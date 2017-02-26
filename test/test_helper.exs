{:ok, files} = File.ls("./test/support")

Enum.each files, fn(file) ->
  Code.require_file "support/#{file}", __DIR__
end

ExUnit.start include: [amqp_server: true]
