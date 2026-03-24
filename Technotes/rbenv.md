# rbenv: Ruby Version Management

## Install rbenv via Homebrew

```bash
brew install rbenv ruby-build
```

Initialize rbenv in your shell:

```bash
rbenv init
```

Follow the printed instructions to add the init line to your shell profile (`~/.zshrc`):

```bash
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc
```

## Install Latest Ruby 3.x

List available Ruby 3.x versions:

```bash
rbenv install -l | grep '^3\.'
```

Install the latest one (e.g. 3.4.9):

```bash
rbenv install 3.4.9
```

Set it as the local default:

```bash
rbenv local 3.4.9
```

Verify:

```bash
ruby -v
```

## Install the xcodeproj Gem

```bash
gem install xcodeproj
```

Verify:

```bash
gem list xcodeproj
```

The `xcodeproj` gem is used in this project to safely modify Xcode project files (`.xcodeproj/project.pbxproj`) instead of editing the pbxproj file directly.
