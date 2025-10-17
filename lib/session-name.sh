#!/bin/bash
# session-name.sh - Generate friendly session names from UUID

# Lists for friendly name generation
ADJECTIVES=(
  "bold" "brave" "bright" "calm" "clever"
  "cool" "cosmic" "crisp" "daring" "eager"
  "fair" "fancy" "fast" "gentle" "glad"
  "grand" "happy" "kind" "lively" "lucky"
  "merry" "noble" "proud" "quick" "quiet"
  "rapid" "smart" "solid" "swift" "warm"
  "wise" "witty" "zesty" "agile" "alert"
)

NOUNS=(
  "bear" "bird" "cat" "deer" "eagle"
  "fish" "fox" "hawk" "lion" "owl"
  "star" "moon" "sun" "wind" "wave"
  "tree" "river" "mountain" "ocean" "cloud"
  "tiger" "wolf" "dragon" "phoenix" "falcon"
  "comet" "galaxy" "planet" "nova" "meteor"
  "forest" "canyon" "valley" "peak" "storm"
)

# Generate friendly name from session ID
# Args: $1 - session_id (UUID)
# Returns: friendly name like "bold-cat" or "swift-eagle"
generate_session_name() {
  local session_id="$1"

  # Return "unknown" if no session_id
  if [[ -z "$session_id" ]] || [[ "$session_id" == "unknown" ]]; then
    echo "unknown-session"
    return
  fi

  # Remove dashes from UUID and convert to lowercase
  local clean_id=$(echo "$session_id" | tr -d '-' | tr '[:upper:]' '[:lower:]')

  # Get first 8 chars for adjective seed, next 8 for noun seed
  local adj_seed="${clean_id:0:8}"
  local noun_seed="${clean_id:8:8}"

  # Convert hex to decimal for array indexing
  local adj_index=$((16#${adj_seed:0:6} % ${#ADJECTIVES[@]}))
  local noun_index=$((16#${noun_seed:0:6} % ${#NOUNS[@]}))

  # Get words from arrays
  local adjective="${ADJECTIVES[$adj_index]}"
  local noun="${NOUNS[$noun_index]}"

  echo "${adjective}-${noun}"
}

export -f generate_session_name
