defmodule Hare.Mixfile do
  use Mix.Project

  def project do
    [app: :hare,
     version: "0.1.3",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "Some abstractions to interact with a AMQP broker",
     package: package,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :connection]]
  end

  defp deps do
    # [{:amqp_client, git: "https://github.com/dsrosario/amqp_client.git", branch: "erlang_otp_19", override: true, optional: true},
    #  {:amqp, "~> 0.1.4", optional: true},
    [{:connection, "~> 1.0"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [maintainers: ["Jaime Cabot"],
     licenses: ["Apache 2"],
     links: %{"GitHub" => "https://github.com/jcabotc/hare"}]
  end
end
