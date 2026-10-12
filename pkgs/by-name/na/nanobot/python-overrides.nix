final: prev:
let
  update =
    pname: version: hash:
    prev.${pname}.overridePythonAttrs {
      inherit version;
      src = final.fetchPypi {
        pname = builtins.replaceStrings [ "-" ] [ "_" ] pname;
        inherit version hash;
      };
    };
in
{
  anthropic =
    (update "anthropic" "0.100.0" "sha256-ZQ3ungI6+xY5WTnuQQS7wh+WazgCEBGfuREiwSCZx5o=")
    .overridePythonAttrs
      (old: {
        nativeCheckInputs = old.nativeCheckInputs ++ [
          final.http-snapshot
          final.boto3
        ];
      });
  pydantic-settings =
    update "pydantic-settings" "2.12.0"
      "sha256-AFU475UePCpo4cCLKStfLnFJDe+FidQiG5XasA2vz9A=";
  json-repair =
    (update "json-repair" "0.57.0" "sha256-aYcZF/XGQm+RPg0AeB/36vEDra5ETrfNZsY0NojiolQ=")
    .overridePythonAttrs
      (old: {
        nativeCheckInputs = old.nativeCheckInputs ++ [ final.jsonschema ];
        # The PyPI source distribution omits this test's JSON fixture.
        disabledTests = [ "test_repair_json_from_file" ];
      });
  rapidfuzz =
    (update "rapidfuzz" "3.14.6" "sha256-4TqBYNAXtJnsei+p0M4a4uc3cICBV4WBn5ZvsjXU62A=")
    .overridePythonAttrs
      {
        # Both taskflow compatibility patches are included in this release.
        patches = [ ];
        # The source distribution no longer declares a Cython version bound.
        postPatch = "";
      };
  filelock = update "filelock" "3.25.2" "sha256-tk7OKzj0yindPoECh6qMSBgrvs0a5umuEmybNfE4JpQ=";
  hatchling = update "hatchling" "1.29.0" "sha256-eTwxgW2VLO5AW4NIjOABxxnzJdnNpp8fxM11BSdkDqY=";
  pypdf = prev.pypdf.overridePythonAttrs rec {
    version = "5.9.0";
    src = prev.pypdf.src.override {
      tag = version;
      hash = "sha256-WM7eAXDdrnbm1olS+3WPF6FhTUbdIHojtGbJdPHvxv4=";
    };
    # Pillow 12.1 deprecates getdata, which this supported pypdf release uses.
    pytestFlags = [ "-Wignore:Image.Image.getdata:DeprecationWarning" ];
  };

  http-snapshot = final.buildPythonPackage rec {
    pname = "http-snapshot";
    version = "0.1.8";
    pyproject = true;

    src = final.fetchPypi {
      pname = "http_snapshot";
      inherit version;
      hash = "sha256-Hw3EN/6k4TF58mKQIWu0AglqRPOymWkCKnjC5x/d/Cg=";
    };

    build-system = [ final.setuptools ];
    dependencies = with final; [
      inline-snapshot
      httpx
      pytest
    ];
    pythonImportsCheck = [ "http_snapshot" ];
  };

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
