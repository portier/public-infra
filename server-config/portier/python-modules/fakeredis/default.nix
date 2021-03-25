{ buildPythonPackage, fetchPypi, redis, six, sortedcontainers }:

buildPythonPackage rec {
  pname = "fakeredis";
  version = "1.5.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1ac0cef767c37f51718874a33afb5413e69d132988cb6a80c6e6dbeddf8c7623";
  };

  doCheck = false;
  propagatedBuildInputs = [ redis six sortedcontainers ];
}
