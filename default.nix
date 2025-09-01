{
  makeDesktopItem,
  buildPythonPackage,
  pythonRelaxDepsHook,
  poetry-core,
  setuptools,
  wheel,
  glib,
  imagemagick,
  requests,
  yarl,
  anitopy,
  appdirs,
  tqdm,
  pylnk3,
  pyqt6,
  cryptography,
  beautifulsoup4,
}: let
  pname = "senpwai";
  version = "2.1.15";

  desktopItem = makeDesktopItem {
    name = "${pname}";
    desktopName = "Senpwai";
    exec = "${pname}";
    icon = "${pname}";
    terminal = false;
    categories = ["Utility"];
  };
in
  buildPythonPackage {
    inherit pname version;

    src = ./.;

    format = "pyproject";

    build-system = [
      setuptools
      wheel
      poetry-core
    ];

    nativeBuildInputs = [
      glib
      pythonRelaxDepsHook
    ];

    propagatedBuildInputs = [
      glib
      wheel
      poetry-core
      requests
      yarl
      anitopy
      appdirs
      tqdm
      pylnk3
      pyqt6
      cryptography
      beautifulsoup4
    ];

    pythonRemoveDeps = [
      "cryptography"
      "argparse"
      "bs4"
    ];

    doCheck = false;
    postInstall = ''
      mkdir -p "$out/share/pixmaps"
      ${imagemagick}/bin/magick $src/senpwai/assets/misc/senpwai-icon.ico "$out/share/pixmaps/${pname}.png"
      cp -r ${desktopItem}/share/applications $out/share
    '';
  }
