defmodule Smovie.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Smovie.Accounts.Visibility

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    # NULL signifie « suivre le navigateur », pas « francais ».
    field :locale, :string

    field :username, :string
    field :display_name, :string
    field :bio, :string
    field :location, :string
    # Prevu pour un televersement ulterieur : en attendant, l'avatar est
    # l'initiale du nom affiche sur une couleur derivee de l'identifiant.
    field :avatar_path, :string

    field :profile_visibility, Visibility, default: :public
    field :watchlist_visibility, Visibility, default: :public
    field :default_review_visibility, Visibility, default: :public

    timestamps(type: :utc_datetime)
  end

  # Reserves parce qu'ils ressemblent a des sections de l'application ou a des
  # comptes de service : un membre nomme « admin » ou « smovie » pretera a
  # confusion, quand bien meme les profils vivent sous /u/.
  @reserved_usernames ~w(
    admin administrateur administrator root smovie support contact api www
    help aide moderation moderateur staff equipe team official officiel
    me moi user users utilisateur membre null undefined
  )

  @doc """
  Changeset de profil public.

  Le nom affiche et la bio sont libres ; le username est contraint parce qu'il
  sert d'adresse (`/u/:username`) : il doit rester lisible, tapable au clavier
  et stable d'une casse a l'autre.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name, :bio, :location])
    |> validate_required([:username, :display_name])
    |> validate_username()
    |> validate_length(:display_name, min: 1, max: 60)
    |> validate_length(:bio, max: 500)
    |> validate_length(:location, max: 80)
  end

  defp validate_username(changeset) do
    changeset
    |> update_change(:username, &String.downcase/1)
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "ne peut contenir que des lettres sans accent, des chiffres et des tirets bas"
    )
    |> validate_exclusion(:username, @reserved_usernames, message: "n'est pas disponible")
    |> unsafe_validate_unique(:username, Smovie.Repo)
    |> unique_constraint(:username)
    |> check_constraint(:username,
      name: :users_username_format,
      message: "ne respecte pas le format attendu"
    )
  end

  @doc """
  Derive un username disponible a partir d'une adresse e-mail.

  Utilise a l'inscription : demander un username au moment ou l'on demande
  deja une adresse ajoute une etape et un motif d'abandon. Le membre le change
  ensuite dans ses parametres.
  """
  def suggest_username(email, taken? \\ fn _ -> false end) do
    base =
      email
      |> String.split("@")
      |> List.first()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_]/, "")
      |> String.slice(0, 26)
      |> pad_if_short()

    if base in @reserved_usernames or taken?.(base) do
      first_available(base, taken?)
    else
      base
    end
  end

  defp first_available(base, taken?) do
    2..999
    |> Stream.map(&"#{base}#{&1}")
    |> Enum.find(&(not taken?.(&1)))
  end

  defp pad_if_short(base) when byte_size(base) >= 3, do: base
  defp pad_if_short(base), do: base <> String.duplicate("0", 3 - byte_size(base))

  @doc """
  Nom affiche par defaut : la partie locale de l'adresse.
  """
  def suggest_display_name(email) do
    case email |> String.split("@") |> List.first() do
      "" -> "Membre"
      local -> local
    end
  end

  @doc """
  Changeset des reglages de visibilite.
  """
  def visibility_changeset(user, attrs) do
    fields = [:profile_visibility, :watchlist_visibility, :default_review_visibility]

    user
    |> cast(attrs, fields)
    |> validate_required(fields)
  end

  @doc """
  Changeset de preference de langue.

  Une locale inconnue est refusee plutot qu'ignoree : accepter n'importe quelle
  chaine ferait rendre l'application dans la langue par defaut sans rien dire a
  l'utilisateur, qui croirait son choix pris en compte.
  """
  def locale_changeset(user, attrs) do
    user
    |> cast(attrs, [:locale])
    |> validate_inclusion(:locale, Smovie.Config.locales())
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_email` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Smovie.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Smovie.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
