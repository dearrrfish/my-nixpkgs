final: prev:
let
  update = pname: version: hash:
    prev.${pname}.overridePythonAttrs {
      inherit version;
      src = final.fetchPypi {
        pname = builtins.replaceStrings [ "-" ] [ "_" ] pname;
        inherit version hash;
      };
    };
in
{
  anthropic = update "anthropic" "0.100.0" "sha256-ZQ3ungI6+xY5WTnuQQS7wh+WazgCEBGfuREiwSCZx5o=";
  pydantic-settings = update "pydantic-settings" "2.12.0" "sha256-AFU475UePCpo4cCLKStfLnFJDe+FidQiG5XasA2vz9A=";
  json-repair = update "json-repair" "0.57.0" "sha256-aYcZF/XGQm+RPg0AeB/36vEDra5ETrfNZsY0NojiolQ=";
  rapidfuzz = update "rapidfuzz" "3.14.6" "sha256-4TqBYNAXtJnsei+p0M4a4uc3cICBV4WBn5ZvsjXU62A=" // { patches = [ ]; };
  filelock = update "filelock" "3.25.2" "sha256-tk7OKzj0yindPoECh6qMSBgrvs0a5umuEmybNfE4JpQ=";

  oauth-cli-kit = final.buildPythonPackage rec {
    pname = "oauth-cli-kit";
    version = "0.1.6";
    pyproject = true;

    src = final.fetchPypi {
      pname = "oauth_cli_kit";
      inherit version;
      hash = "sha256-clL1fhovnbp6lIlMEbl5+DiEs8iK87T+AgY3CisSBJk=";
    };

    build-system = with final; [
      hatchling
      hatch-vcs
    ];
    dependencies = with final; [
      httpx
      platformdirs
    ];
    pythonImportsCheck = [ "oauth_cli_kit" ];
  };
}
