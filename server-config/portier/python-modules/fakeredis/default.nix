{ buildPythonPackage, fetchPypi, redis, six, sortedcontainers }:

buildPythonPackage rec {
  pname = "fakeredis";
  version = "1.4.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "bcb2faeabb1bd7ff2fecaff9b2a47ebfaf31700ee260a2ef66c6cf041d7a78df";
  };

  doCheck = false;
  propagatedBuildInputs = [ redis six sortedcontainers ];
}
