class Kleopatra < Formula
  desc "Certificate manager and GUI for OpenPGP and CMS cryptography"
  homepage "https://invent.kde.org/pim/kleopatra"
  url "https://github.com/KDE/kleopatra/archive/refs/tags/v22.07.80.tar.gz"
  sha256 "92642a820fe8ca17b8ba29f8c8e72023765a075422fb37eef82d85bf67729a25"
  license all_of: ["GPL-2.0-only", "GPL-3.0-only", "LGPL-2.1-only", "LGPL-3.0-only"]
  keg_only "not linked to prevent conflicts with any gpgme or kde libs"

  bottle do
    root_url "https://github.com/algertc/homebrew-kleopatra4mac/releases/download/latest"
    sha256 monterey: "5a3a4892a6ba475bd7e759dc08b4537182964b0fe650545c383aba921ad12803"
    sha256 arm64_monterey: "b3a7b265427c680b16bf1dacc03ebf6b4c5c3a7d96d5fd13b067cc0b50946467"
  end

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "extra-cmake-modules" => :build
  depends_on "iso-codes" => :build
  depends_on "pkg-config" => :build
  depends_on "python3" => :build
  depends_on "dbus"
  depends_on "docbook-xsl"
  depends_on "gnupg"
  depends_on "libassuan"
  depends_on "libgpg-error"
  depends_on "qt@5"
  depends_on "zstd"
  uses_from_macos "zip"

  # qgpgme, gpgmepp
  resource "gpgme" do
    url "https://www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.17.1.tar.bz2"
    sha256 "711eabf5dd661b9b04be9edc9ace2a7bc031f6bd9d37a768d02d0efdef108f5f"
  end

  resource "gpgmepp" do
    url "https://github.com/KDE/gpgmepp/archive/refs/tags/v16.08.3.tar.gz"
    sha256 "b988830a88448703128bc2bd2830e8aad2732b3ad45b6f26360b8da358cd9a96"
  end

  # knotifications depends on it
  resource "phonon" do
    url "https://github.com/KDE/phonon/archive/refs/tags/v4.11.1.tar.gz"
    sha256 "94e782d1499a7b264122cf09aa559d6245b869d4c33462d82dd1eb294c132e1b"
  end

  # ktextwidgets depends on it
  resource "sonnet" do
    url "https://github.com/KDE/sonnet/archive/refs/tags/v5.96.0.tar.gz"
    sha256 "df94279e92c8b5069a5524e00fa236cc6d66e7a356d25bbc266808a6770518f2"
  end

  # KF5 libraries
  resource "karchive" do
    url "https://github.com/KDE/karchive/archive/refs/tags/v5.96.0.tar.gz"
    sha256 "5870cee093d2e079009f9c88a36eb59bc9880b57623232ccaa49ef3ae1a0d405"
  end

  # ... (other resources)

  def install
    args = std_cmake_args

    # qgpgme, gpgmepp
    resource("gpgme").stage do
      system "./configure", "--prefix=#{prefix}"
      inreplace "lang/qt/src/Makefile" do |s|
        s.gsub!(/\-std=c\+\+11/, "-std=c++17")
      end
      inreplace "lang/qt/tests/Makefile" do |s|
        s.gsub!(/\-std=c\+\+11/, "-std=c++17")
      end
      system "make", "install"
    end

    resource("gpgmepp").stage do
      system "cmake", ".", *args
      system "make", "install", "prefix=#{prefix}"
    end

    # ... (installation steps for other resources)

    # hide away gpgme++ from kf5, we need gpgme files
    chdir "#{prefix}/include/KF5" do
      system "mv", "gpgme++", "gpgme++.not.used"
    end

    resource("libkleo").stage do
      system "cmake", ".", *args
      system "make", "install", "prefix=#{prefix}"
    end

    inreplace "src/dialogs/certificatedetailswidget.cpp" do |s|
      s.gsub!(/ifdef USE_RANGES/, "if 0")
    end

    inreplace "src/view/padwidget.cpp" do |s|
      s.gsub!(/QStringLiteral\(\"Monospace\"\)/, "QFontDatabase::systemFont(QFontDatabase::FixedFont)")
    end

    system "cmake", ".", *args
    inreplace "src/cmake_install.cmake" do |s|
      s.gsub!(/\"\/Applications\/KDE\"/, "\"/#{prefix}/Applications/KDE\"")
    end
    inreplace "src/kwatchgnupg/cmake_install.cmake" do |s|
      s.gsub!(/\"\/Applications\/KDE\"/, "\"/#{prefix}/Applications/KDE\"")
    end
    system "make", "install"

    kleopatra = "#{prefix}/Applications/KDE/kleopatra.app/Contents/MacOS/kleopatra"
    system "install_name_tool", "-add_rpath", "#{prefix}/lib", kleopatra
    system "install_name_tool", "-add_rpath", "#{HOMEBREW_PREFIX}/lib", kleopatra
  end

  test do
    k = "#{prefix}/Applications/KDE/kleopatra.app/Contents/MacOS/kleopatra"
    system k, "--help"
  end

  def caveats
    <<~EOS
    After Installing:
    Make sure dbus is running
      brew services start dbus
    Select pinentry-mac as the default program
      brew install pinentry-mac
      echo "pinentry-program #{HOMEBREW_PREFIX}/bin/pinentry-mac" > ~/.gnupg/gpg-agent.conf
      killall -9 gpg-agent
    There is a clean PATH method below to run 'kleopatra', but it is also ok to create a quick symlink using
      ln -s #{opt_prefix}/bin/kleopatra #{HOMEBREW_PREFIX}/bin/
    If you want to add this application to the Launchpad
      cd /Applications && unzip #{opt_prefix}/app.zip
    EOS
  end

  def post_install
    zip = "#{opt_prefix}/zip/kleopatra.app"
    src = "#{opt_prefix}/Applications/KDE/kleopatra.app"
    chdir src do
      system "sh", "-c", "find . | while read a; do if [ -d $a ]; then mkdir -p #{zip}/$a; else cp #{src}/$a #{zip}/$a; fi; done"
    end
    system "chmod", "+w", "#{zip}/Contents/MacOS/kleopatra"
    File.write "#{zip}/Contents/MacOS/kleopatra", <<~EOS
    #!/bin/sh
    PATH=#{HOMEBREW_PREFIX}/bin:$PATH
    exec #{src}/Contents/MacOS/kleopatra
    EOS
    chdir "#{opt_prefix}/zip" do
      system "zip", "-r", "#{opt_prefix}/app.zip", "."
    end
    system "ln", "-sf", "#{src}/Contents/MacOS/kleopatra", "#{opt_prefix}/bin/kleopatra"
  end
end
