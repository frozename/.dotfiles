# =========================================================
# ZSHRC v11 - modular shell baseline
# =========================================================

DOTFILES_ZSH_DIR="${DOTFILES_ZSH_DIR:-$HOME/.zsh}"

for zsh_module in env shell bun tools repos aliases llm; do
  if [ -f "$DOTFILES_ZSH_DIR/$zsh_module.zsh" ]; then
    source "$DOTFILES_ZSH_DIR/$zsh_module.zsh"
  fi
done

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
