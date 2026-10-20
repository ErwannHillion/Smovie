defmodule Smovie.MessagingTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Messaging
  alias Smovie.Messaging.Conversation
  alias Smovie.Repo
  alias Smovie.Social

  setup do
    moi = user_fixture()
    autre = user_fixture()
    %{moi: moi, scope: Scope.for_user(moi), autre: autre, autre_scope: Scope.for_user(autre)}
  end

  describe "conversations privees" do
    test "s'ouvrent et se retrouvent", %{scope: scope, autre: autre} do
      {:ok, a} = Messaging.find_or_create_direct(scope, autre)
      {:ok, b} = Messaging.find_or_create_direct(scope, autre)

      assert a.id == b.id
      assert Repo.aggregate(Conversation, :count) == 1
    end

    test "la cle ignore l'ordre des identifiants", %{
      scope: scope,
      autre: autre,
      autre_scope: autre_scope,
      moi: moi
    } do
      # Sans normalisation, (3, 7) et (7, 3) donneraient deux cles et
      # l'unicite ne servirait a rien.
      {:ok, a} = Messaging.find_or_create_direct(scope, autre)
      {:ok, b} = Messaging.find_or_create_direct(autre_scope, moi)

      assert a.id == b.id
    end

    test "refuse de se parler a soi-meme", %{scope: scope, moi: moi} do
      assert Messaging.find_or_create_direct(scope, moi) == {:error, :cannot_message_self}
    end

    test "portent le nom de l'autre personne", %{
      scope: scope,
      autre: autre,
      autre_scope: autre_scope,
      moi: moi
    } do
      # Une conversation privee n'a pas de titre : il change selon qui regarde.
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      conversation = Repo.preload(conversation, members: :user)

      assert Messaging.title(conversation, scope) == autre.display_name
      assert Messaging.title(conversation, autre_scope) == moi.display_name
    end
  end

  describe "groupes" do
    test "se creent avec leurs membres", %{scope: scope, autre: autre} do
      {:ok, groupe} = Messaging.create_group(scope, "Les Cinevores", [autre.id])

      assert groupe.kind == :group
      assert length(Messaging.active_members(groupe)) == 2
    end

    test "le createur en est proprietaire", %{scope: scope, autre: autre} do
      {:ok, groupe} = Messaging.create_group(scope, "Les Cinevores", [autre.id])
      groupe = Repo.preload(groupe, members: :user)

      assert Messaging.admin?(scope, groupe)
      refute Messaging.admin?(Scope.for_user(autre), groupe)
    end

    test "refusent un titre vide", %{scope: scope, autre: autre} do
      assert {:error, changeset} = Messaging.create_group(scope, "", [autre.id])
      assert errors_on(changeset)[:title]
    end
  end

  describe "autorisations" do
    setup %{scope: scope, autre: autre} do
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      %{conversation: Repo.preload(conversation, members: :user)}
    end

    test "un tiers n'est pas membre", %{conversation: conversation} do
      tiers = Scope.for_user(user_fixture())

      assert Messaging.authorize_member(tiers, conversation) == {:error, :not_a_member}
      assert Messaging.get_conversation(tiers, conversation.id) == {:error, :not_a_member}
    end

    test "les raisons d'echec sont distinctes", %{conversation: conversation, scope: scope} do
      # L'interface doit pouvoir dire « vous n'etes pas membre » plutot que
      # « acces refuse ».
      assert Messaging.authorize_member(scope, conversation) == :ok

      Repo.update_all(Smovie.Messaging.ConversationMember,
        set: [left_at: DateTime.utc_now(:second)]
      )

      assert Messaging.authorize_member(scope, conversation) == {:error, :left_conversation}
    end

    test "un identifiant illisible donne une absence", %{scope: scope} do
      assert Messaging.get_conversation(scope, "abc") == {:error, :not_found}
    end
  end

  describe "messages" do
    setup %{scope: scope, autre: autre} do
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      %{conversation: Repo.preload(conversation, members: :user)}
    end

    test "s'envoient", %{scope: scope, conversation: conversation} do
      assert {:ok, message} = Messaging.send_message(scope, conversation, %{"body" => "Salut"})
      assert message.body == "Salut"
      assert [%{body: "Salut"}] = Messaging.list_messages(conversation)
    end

    test "refusent un corps vide", %{scope: scope, conversation: conversation} do
      assert {:error, changeset} = Messaging.send_message(scope, conversation, %{"body" => "  "})
      assert errors_on(changeset)[:body]
    end

    test "mettent la conversation en tete", %{scope: scope, conversation: conversation} do
      Messaging.send_message(scope, conversation, %{"body" => "Salut"})

      assert Repo.reload!(conversation).last_message_at
    end

    test "sont refuses a un tiers", %{conversation: conversation} do
      tiers = Scope.for_user(user_fixture())

      assert Messaging.send_message(tiers, conversation, %{"body" => "Coucou"}) ==
               {:error, :not_a_member}
    end

    test "annoncent leur arrivee sur PubSub", %{scope: scope, conversation: conversation} do
      Phoenix.PubSub.subscribe(Smovie.PubSub, Messaging.topic(conversation))

      Messaging.send_message(scope, conversation, %{"body" => "Salut"})

      assert_receive {:new_message, %{body: "Salut"}}
    end

    test "notifient les autres membres", %{
      scope: scope,
      autre_scope: autre_scope,
      conversation: conversation
    } do
      Messaging.send_message(scope, conversation, %{"body" => "Salut"})

      assert [%{kind: :new_message}] = Social.list_notifications(autre_scope)
    end

    test "se paginent par curseur", %{scope: scope, conversation: conversation} do
      for n <- 1..5, do: Messaging.send_message(scope, conversation, %{"body" => "m#{n}"})

      [premier | _] = page = Messaging.list_messages(conversation, limit: 2)
      assert length(page) == 2

      suivants = Messaging.list_messages(conversation, limit: 2, before_id: premier.id)

      assert length(suivants) == 2
      assert Enum.all?(suivants, &(&1.id < premier.id))
    end
  end

  describe "suppression d'un message" do
    setup %{scope: scope, autre: autre} do
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      conversation = Repo.preload(conversation, members: :user)
      {:ok, message} = Messaging.send_message(scope, conversation, %{"body" => "A effacer"})

      %{conversation: conversation, message: message}
    end

    test "son auteur le peut", %{scope: scope, message: message} do
      # Le message est marque, pas efface : une bulle « message supprime »
      # garde le fil lisible, la ou un trou laisserait croire a un bug.
      assert {:ok, supprime} = Messaging.delete_message(scope, message)
      assert supprime.deleted_at
      assert supprime.body == nil
    end

    test "un autre membre ne le peut pas", %{autre_scope: autre_scope, message: message} do
      assert Messaging.delete_message(autre_scope, message) == {:error, :not_allowed}
    end
  end

  describe "partage d'une review" do
    setup %{scope: scope, autre: autre} do
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      %{conversation: Repo.preload(conversation, members: :user), auteur: user_fixture()}
    end

    test "accepte une review publique", %{
      scope: scope,
      conversation: conversation,
      auteur: auteur
    } do
      review = review_fixture(auteur, movie_fixture())

      assert {:ok, _message} =
               Messaging.send_message(scope, conversation, %{
                 "kind" => "review_share",
                 "shared_review_id" => review.id
               })
    end

    test "refuse une review que tous les membres ne voient pas", %{
      scope: scope,
      conversation: conversation,
      auteur: auteur
    } do
      # Partager une review reservee aux abonnes dans un groupe ou quelqu'un
      # ne suit pas l'auteur ferait fuiter son contenu.
      review = review_fixture(auteur, movie_fixture(), %{"visibility" => "followers"})
      Social.follow(scope, auteur)

      assert Messaging.send_message(scope, conversation, %{
               "kind" => "review_share",
               "shared_review_id" => review.id
             }) == {:error, :review_not_visible_to_all}
    end
  end

  describe "non-lus" do
    setup %{scope: scope, autre: autre} do
      {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
      %{conversation: Repo.preload(conversation, members: :user)}
    end

    test "comptent les messages des autres", %{
      scope: scope,
      autre_scope: autre_scope,
      conversation: conversation
    } do
      Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})

      assert Messaging.unread_count(scope) == 1
    end

    test "ne comptent pas ses propres messages", %{scope: scope, conversation: conversation} do
      # Ils seraient toujours non lus par definition.
      Messaging.send_message(scope, conversation, %{"body" => "Salut"})

      assert Messaging.unread_count(scope) == 0
    end

    test "s'eteignent a la lecture", %{
      scope: scope,
      autre_scope: autre_scope,
      conversation: conversation
    } do
      Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})
      Messaging.mark_read(scope, conversation)

      assert Messaging.unread_count(scope) == 0
    end

    test "valent zero pour un visiteur" do
      assert Messaging.unread_count(nil) == 0
    end
  end
end
