class Powerai < Formula
  desc "Invisible, zero-dependency local-first terminal AI harness using Ollama"
  homepage "https://luizhcrs.github.io/powerai/"
  url "https://github.com/Luizhcrs/powerai/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "SKIP" # Computed on release
  license "PolyForm-Noncommercial-1.0.0"

  depends_on "jq"
  depends_on "curl"

  def install
    pkgshare.install "powerai.sh"
    pkgshare.install "powerai.fish"
    pkgshare.install "uninstall.sh"
    bin.install_symlink pkgshare/"powerai.sh" => "powerai"
  end

  def caveats
    <<~EOS
      ✦ PowerAI has been installed!

      To activate PowerAI in your current shell, add this line to your config:

      For Zsh (~/.zshrc):
        source #{opt_pkgshare}/powerai.sh

      For Bash (~/.bashrc):
        source #{opt_pkgshare}/powerai.sh

      For Fish (~/.config/fish/config.fish):
        source #{opt_pkgshare}/powerai.fish
    EOS
  end

  test do
    assert_match "PowerAI", shell_output("bash -c 'source #{pkgshare}/powerai.sh && ai version'")
  end
end
