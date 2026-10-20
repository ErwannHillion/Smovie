# Doublures des clients externes.
#
# Aucun test ne doit sortir sur le reseau : TMDB plafonne le debit, et une
# suite qui depend du reseau echoue pour des raisons qui n'ont rien a voir
# avec le code.
Mox.defmock(Smovie.External.TMDBMock, for: Smovie.External.TMDB)
