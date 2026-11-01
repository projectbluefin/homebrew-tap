cask "bluefin-report" do
  arch arm: "arm64", intel: "amd64"

  version "26.11.2"
  sha256 arm64_linux:  "92a4f973dad2499d5fb1249134199debfe0c374e2b175d2947fa46a79cbc1e67",
         x86_64_linux: "35ee31e290a0a7b1090d3d00d119f879f349b758ecd3c20fe6caefc211f735df"

  url "https://github.com/projectbluefin/bluefin-report/releases/download/#{version}/bluefin-report_#{version}_linux_#{arch}.tar.gz"
  name "Report a problem"
  desc "Review and share a privacy-scrubbed systemd-report as a GitHub issue"
  homepage "https://github.com/projectbluefin/bluefin-report"

  livecheck do
    url :url
    strategy :github_releases do |releases|
      releases.filter_map do |release|
        next if release["draft"] || release["prerelease"]

        release["tag_name"]&.delete_prefix("v")
      end
    end
  end

  depends_on formula: "gh"
  depends_on :linux

  binary "bluefin-report"
  binary "data/bluefin-report-wrapper.sh", target: "bluefin-report-wrapper"

  preflight_steps do
    # Menu launches need the brew environment so gh is found.
    inreplace "data/bluefin-report-wrapper.sh", "/home/linuxbrew/.linuxbrew/bin/brew", "{{HOMEBREW_PREFIX}}/bin/brew"
    inreplace "data/bluefin-report-wrapper.sh", "$BREW_PATH shellenv", "\"$BREW_PATH\" shellenv bash"
    inreplace "data/bluefin-report-wrapper.sh", "exec bluefin-report",
              "exec \"{{HOMEBREW_PREFIX}}/bin/bluefin-report\""
    inreplace "data/io.projectbluefin.Report.desktop", "Exec=bluefin-report",
              "Exec=\"{{HOMEBREW_PREFIX}}/bin/bluefin-report-wrapper\""
  end

  postflight_steps do
    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons/hicolor/scalable/apps", base: :home
    mkdir_p ".local/share/icons/hicolor/symbolic/apps", base: :home
    copy "data/io.projectbluefin.Report.desktop", ".local/share/applications/io.projectbluefin.Report.desktop",
         target_base: :home
    copy "data/icons/hicolor/scalable/apps/io.projectbluefin.Report.svg",
         ".local/share/icons/hicolor/scalable/apps/io.projectbluefin.Report.svg", target_base: :home
    copy "data/icons/hicolor/symbolic/apps/io.projectbluefin.Report-symbolic.svg",
         ".local/share/icons/hicolor/symbolic/apps/io.projectbluefin.Report-symbolic.svg", target_base: :home
  end

  uninstall_postflight_steps do
    remove [".local/share/applications/io.projectbluefin.Report.desktop",
            ".local/share/icons/hicolor/scalable/apps/io.projectbluefin.Report.svg",
            ".local/share/icons/hicolor/symbolic/apps/io.projectbluefin.Report-symbolic.svg"], base: :home
  end

  caveats <<~EOS
    Report a problem requires systemd 261 or newer with systemd-report, and
    GTK 4 / libadwaita 1 shared libraries from your OS. Publishing to GitHub
    needs `gh auth login`; the app can start sign-in for you.
  EOS
end
