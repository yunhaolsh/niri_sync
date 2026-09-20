{ pkgs, ... }:

{
  # Replace the ad-hoc files copied by the old migration workflow.
  home.file.".bashrc".force = true;
  home.file.".profile".force = true;
  home.file.".gitconfig" = {
    force = true;
    text = ''
      [user]
        name = yunhao1
        email = yunhao1@lenovo.com
      [init]
        defaultBranch = main
      [credential "https://github.com"]
        helper = !/usr/bin/gh auth git-credential
      [credential "https://gist.github.com"]
        helper = !/usr/bin/gh auth git-credential
    '';
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
    initExtra = ''
      eval "$(${pkgs.starship}/bin/starship init bash)"
      eval "$(${pkgs.atuin}/bin/atuin init bash)"
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"

      export PYENV_ROOT="$HOME/.pyenv"
      eval "$(${pkgs.pyenv}/bin/pyenv init - bash)"

      if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniforge3/etc/profile.d/conda.sh"
      fi

      unset OPENAI_API_KEY CODEX_API_KEY OPENAI_BASE_URL
    '';
  };

}
