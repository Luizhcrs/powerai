# powerai.fish - Native Fish Shell Integration for PowerAI
# Usage: source ~/.powerai/powerai.fish or auto-loaded via ~/.config/fish/conf.d/powerai.fish

function ai --description "PowerAI Terminal Copilot & Cognitive Harness"
    if test (count $argv) -eq 0
        bash -c "source $HOME/.powerai/powerai.sh && _powerai_ai_entry"
        return 0
    end
    
    # Forward all arguments directly to PowerAI engine
    bash -c "source $HOME/.powerai/powerai.sh && _powerai_ai_entry \"\$@\"" -- $argv
end

# Alias ? shorthand for Fish
function '?' --description "PowerAI Fast Shorthand"
    ai $argv
end

# Fish Command Not Found Event Handler
function __powerai_command_not_found_handler --on-event fish_command_not_found
    set -l failed_cmd "$argv"
    echo "fish: Unknown command '$argv[1]'" >&2
    bash -c "source $HOME/.powerai/powerai.sh && _powerai_query \"\$@\" true" -- $failed_cmd
end
