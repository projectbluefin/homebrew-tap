cask "bluefin-wallpapers-extra" do
  version "2026-10-12"
  sha256 "1aaa25a82da8670145d67bd4da25852cd29103ac1fc6210169f33baaded02f5b"

  url "https://github.com/projectbluefin/artwork/releases/download/bluefin-extra-v#{version}/bluefin-wallpapers-extra-gnome.tar.zstd"
  name "bluefin-wallpapers-extra"
  desc "Extra Wallpapers for Bluefin"
  homepage "https://github.com/projectbluefin/artwork"

  livecheck do
    url "https://github.com/projectbluefin/artwork.git"
    regex(/bluefin-extra-v?(\d{4}-\d{2}-\d{2})/)
    strategy :github_releases
  end

  depends_on :linux

  preflight_steps do
    on_linux do
      symlink ".", ".user-home", source_base: :home, overwrite: true
      run "/bin/sh", args: ["-eu", "-c", <<~'SH'], chdir: "{{staged_path}}"
        WALLPAPER_HOME=$(readlink .user-home)
        replacement=$(printf '%s' "$WALLPAPER_HOME" | sed 's/[\\&|]/\\&/g')
        find . -type f -name '*.xml' -exec sed -i.brew-home-backup "s|~|$replacement|g" {} +
        find . -type f -name '*.xml.brew-home-backup' -delete
      SH
    end
  end

  postflight_steps do
    on_linux do
      mkdir_p ".local/share/backgrounds/bluefin", base: :home
      mkdir_p ".local/share/wallpapers/bluefin", base: :home
      mkdir_p ".local/share/gnome-background-properties", base: :home
      run "/bin/bash", chdir: "{{staged_path}}",
                       env: { "WALLPAPER_HOME" => "{{staged_path}}/.user-home" },
                       writable_paths: [".local/share/backgrounds/bluefin", ".local/share/wallpapers/bluefin",
                                        ".local/share/gnome-background-properties"], writable_base: :home,
                       args: ["-eu", "-c", <<~SH]
                         shopt -s nullglob
                         destination="$WALLPAPER_HOME/.local/share/backgrounds/bluefin"
                         for file in "$PWD"/images/*; do
                           filename=$(basename "$file")
                           folder=${filename%.*}
                           folder=${folder//-night/}
                           folder=${folder//-day/}
                           mkdir -p "$destination/$folder"
                           ln -sfn "$file" "$destination/$folder/$filename"
                         done
                         for file in "$PWD"/gnome-background-properties/*; do
                           ln -sfn "$file" "$WALLPAPER_HOME/.local/share/gnome-background-properties/$(basename "$file")"
                         done
                       SH
    end
  end

  uninstall_postflight_steps do
    on_linux do
      remove [".local/share/backgrounds/bluefin/**/*", ".local/share/wallpapers/bluefin/**/*",
              ".local/share/gnome-background-properties/*.xml"],
             base: :home, symlink_target_contains: "/bluefin-wallpapers-extra/"
    end
  end

  zap trash: [
    "#{Dir.home}/.local/share/backgrounds/bluefin",
    "#{Dir.home}/.local/share/gnome-background-properties/duality.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/dusk.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/eyes.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/huntress.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/lazy-days.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/leaf-collector.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/prey.xml",
    "#{Dir.home}/.local/share/gnome-background-properties/tenacious-pterosaur.xml",
    "#{Dir.home}/.local/share/wallpapers/bluefin",
  ]
end
