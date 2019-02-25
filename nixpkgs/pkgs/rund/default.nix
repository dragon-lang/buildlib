{ stdenv, fetchFromGitHub
, version ? "0.0.1"
, gitsha256 ? "1wp4fg4xgj6irnmgk7dw9x50d0fc6919mbsvc9xq9psfm6fq1c1c"
, dmd, ldc
, dcompiler ? "ldc"
}:

stdenv.mkDerivation {
  name = "rund-${version}";
  inherit dmd ldc dcompiler;
  srcs = [
    (fetchFromGitHub {
      owner = "dragon-lang";
      repo = "rund";
      rev = version;
      sha256 = gitsha256;
      name = "rund";
    })
  ];
  buildPhase = ''
    if [ "$dcompiler" == "dmd" ]; then
      PATH=${dmd}/bin:$PATH
      dcompiler_name=dmd
    elif [ "$dcompiler" == "ldc" ]; then
      PATH=${ldc}/bin:$PATH
      dcompiler_name=ldmd2
    else
      echo Error: unknown dcompiler: $dcompiler
      exit 1
    fi
    echo using dcompiler $dcompiler_name
    $dcompiler_name -i -Isrc -run make.d build
  '';
  installPhase = ''
    mkdir $out
    mkdir $out/bin
    cp bin/rund $out/bin
  '';
  meta = with stdenv.lib; {
    description = "A compiler-wrapper that runs and caches D programs";
    license = licenses.boost;
  };
}

