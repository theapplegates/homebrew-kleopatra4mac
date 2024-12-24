class Kleopatra < Formula
  desc "Certificate manager and GUI for OpenPGP and CMS cryptography"
  homepage "https://invent.kde.org/pim/kleopatra"
  url "https://download.kde.org/stable/release-service/23.08.4/src/kleopatra-23.08.4.tar.xz"
  sha256 "c0f9c0d78e2a5773c5d884d8a6915927eb3c70dc1f0d8f51e86e49e8465ea114"
  license all_of: ["GPL-2.0-only", "GPL-3.0-only", "LGPL-2.1-only", "LGPL-3.0-only"]
  keg_only "not linked to prevent conflicts with any gpgme or kde libs"

  depends_on "boost" => :build
  depends_on "cmake" => [:build, "3.20"]
  depends_on "extra-cmake-modules" => :build
  depends_on "ninja" => :build
  depends_on "iso-codes" => :build
  depends_on "pkg-config" => :build
  depends_on "python3" => :build

  depends_on "dbus"
  depends_on "docbook-xsl"
  depends_on "gnupg"
  depends_on "libassuan"
  depends_on "libgpg-error"
  depends_on "qt@6"  # Upgraded to Qt6
  depends_on "zstd"

  uses_from_macos "zip"

  # Updated GPGME version
  resource "gpgme" do
    url "https://www.gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2"
    sha256 "9499e8b1f33cccb6815527a1bc16049d35a6198a6c5fae0185f2bd561bce5224"
  end

  # Updated KDE Frameworks versions to 5.115.0
  %w[karchive kcoreaddons kauth kcodecs kconfig kwidgetsaddons kcompletion
     kguiaddons ki18n kconfigwidgets kcrash kwindowsystem kdbusaddons kdoctools
     kitemviews kiconthemes kitemmodels knotifications ktextwidgets kxmlgui].each do |kf5|
    resource kf5 do
      url "https://download.kde.org/stable/frameworks/5.115/#{kf5}-5.115.0.tar.xz"
      sha256 # You'll need to add the actual sha256 for each framework
    end
  end

  # Updated Phonon
  resource "phonon" do
    url "https://download.kde.org/stable/phonon/4.12.0/phonon-4.12.0.tar.xz"
    sha256 "3287ffe0fbcc2d87c4d7787ee5ab64d5ecb68ab88fac1c4c3dc97f11432dd4b7"
  end

  def install
    # Set up modern CMake args
    args = std_cmake_args + %W[
      -GNinja
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_TESTING=OFF
      -DCMAKE_CXX_STANDARD=17
      -DCMAKE_INSTALL_RPATH=#{lib}
      -DCMAKE_PREFIX_PATH=#{Formula["qt@6"].opt_prefix}
      -DKDE_INSTALL_BUNDLEDIR=#{prefix}/Applications/KDE
    ]

    # Install GPGME with Qt6 support
    resource("gpgme").stage do
      system "./configure", "--prefix=#{prefix}",
                          "--enable-languages=cpp,qt6",
                          "--with-qt6-moc=#{Formula["qt@6"].opt_bin}/moc"
      system "make", "install"
    end

    # Install KDE Frameworks
    %w[karchive kcoreaddons kauth kcodecs kconfig kwidgetsaddons kcompletion
       kguiaddons ki18n kconfigwidgets kcrash kwindowsystem kdbusaddons kdoctools
       kitemviews kiconthemes kitemmodels knotifications ktextwidgets kxmlgui].each do |kf5|
      resource(kf5).stage do
        system "cmake", "-S", ".", "-B", "build", *args
        system "cmake", "--build", "build"
        system "cmake", "--install", "build"
      end
    end

    # Build Kleopatra
    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Create application bundle
    bundle_path = prefix/"Applications/KDE/kleopatra.app"
    executable_path = bundle_path/"Contents/MacOS/kleopatra"

    # Add necessary RPATHs
    system "install_name_tool", "-add_rpath", HOMEBREW_PREFIX/"lib", executable_path
  end

  def post_install
    # Create distributable app bundle
    bundle_path = prefix/"Applications/KDE/kleopatra.app"
    zip_path = opt_prefix/"kleopatra.app.zip"
    
    system "ditto", "-ck", bundle_path, zip_path
    
    # Create convenient symlink
    bin.install_symlink prefix/"Applications/KDE/kleopatra.app/Contents/MacOS/kleopatra"
  end

  def caveats
    <<~EOS
      To complete the installation:

      1. Start dbus:
         brew services start dbus

      2. Configure pinentry-mac:
         brew install pinentry-mac
         echo "pinentry-program #{HOMEBREW_PREFIX}/bin/pinentry-mac" > ~/.gnupg/gpg-agent.conf
         killall -9 gpg-agent

      3. Optional: Install to Applications folder:
         cd /Applications && unzip #{opt_prefix}/kleopatra.app.zip

      Kleopatra can be run directly using:
         kleopatra
    EOS
  end

  test do
    assert_match "Kleopatra", shell_output("#{prefix}/Applications/KDE/kleopatra.app/Contents/MacOS/kleopatra --version")
  end
end
