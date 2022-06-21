{:ok, pid} = Remetente.start_link()
for _ <- 1..10 , do: pid |> Remetente.flip()
