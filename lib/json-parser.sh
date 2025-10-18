#!/bin/bash
# json-parser.sh — кроссплатформенные утилиты для JSON/JSONL без новых зависимостей
# Предпочитает jq, на Windows использует PowerShell, на *nix — python3/python/ruby.

_JSON_PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_JSON_PARSER_DIR}/platform.sh"

# Вспомогательная: выбрать доступный backend
_json_backend() {
  if command_exists jq; then
    echo "jq"
    return
  fi
  local os
  os="$(detect_os)"
  if [[ "$os" == "windows" ]] && command_exists powershell; then
    echo "powershell"
    return
  fi
  if command_exists python3; then
    echo "python3"
    return
  fi
  if command_exists python; then
    echo "python"
    return
  fi
  if command_exists ruby; then
    echo "ruby"
    return
  fi
  echo "none"
}

# Преобразовать dot‑path в jq‑выражение (числовые сегменты → индексы массива)
_jq_expr_from_dot_path() {
  local path="$1"
  # Пример: .obj.arr.0.t → .obj.arr[0].t
  echo "$path" | sed -E 's/\.([0-9]+)(\.|$)/[\1]\2/g'
}

# Получить значение по dot‑пути из JSON (stdin). Если нет — вернуть default (второй аргумент)
# Использование: echo "$json" | json_get ".notifications.webhook.enabled" "false"
json_get() {
  local path="$1"
  local default_value="$2"
  local input
  input="$(cat)"

  if [[ -z "$input" ]]; then
    [[ -n "$default_value" ]] && echo "$default_value"
    return
  fi

  local backend
  backend="$(_json_backend)"
  case "$backend" in
    jq)
      # Безопасно: если нет — пусто; затем подставим default внизу
      local out
      local jq_path
      jq_path="$(_jq_expr_from_dot_path "$path")"
      # Используем try/catch, чтобы отличать отсутствующее значение от false; null считаем пустым
      out="$(printf "%s" "$input" | jq -rc "try (${jq_path}) catch empty" 2>/dev/null)"
      if [[ "$out" == "null" ]]; then out=""; fi
      if [[ -z "$out" && -n "$default_value" ]]; then echo "$default_value"; else echo "$out"; fi
      ;;
    powershell)
      # Dot‑path только (без jq‑выражений)
      local ps
      ps=''
      ps+='$json = [Console]::In.ReadToEnd();'
      ps+='if ([string]::IsNullOrEmpty($json)) { exit 0 }'
      ps+='try {'
      ps+='  $obj = $json | ConvertFrom-Json -Depth 200'
      ps+='  $path = '"'${path}'"';'
      ps+='  $val = $obj'
      ps+='  foreach ($seg in $path.Split(".")) {'
      ps+='    if ($null -eq $val) { break }'
      ps+='    if ($seg -match "^\\d+$") {'
      ps+='      $idx = [int]$seg'
      ps+='      if ($val -is [System.Collections.IList] -and $val.Count -gt $idx) { $val = $val[$idx] } else { $val = $null }'
      ps+='    } else {'
      ps+='      $prop = $val.PSObject.Properties[$seg]'
      ps+='      if ($null -eq $prop) { $val = $null } else { $val = $prop.Value }'
      ps+='    }'
      ps+='  }'
      ps+='  if ($null -eq $val) { "" }'
      ps+='  elseif ($val -is [string]) { $val }'
      ps+='  elseif ($val -is [bool]) { if ($val) { "true" } else { "false" } }'
      ps+='  else { $val | ConvertTo-Json -Depth 200 -Compress }'
      ps+='} catch { "" }'
      local out
      out="$(printf "%s" "$input" | powershell -NoProfile -Command "$ps" 2>/dev/null | tr -d '\r')"
      if [[ -z "$out" && -n "$default_value" ]]; then echo "$default_value"; else echo "$out"; fi
      ;;
    python3|python)
      local py
      py='
import sys, json
data=sys.stdin.read()
if not data:
    sys.exit(0)
try:
    obj=json.loads(data)
except Exception:
    print("")
    sys.exit(0)
path="''""${path}""''"
cur=obj
for seg in path.split('.'):
    if cur is None:
        break
    if isinstance(cur, list) and seg.isdigit():
        idx=int(seg)
        cur = cur[idx] if 0 <= idx < len(cur) else None
    elif isinstance(cur, dict):
        cur = cur.get(seg)
    else:
        cur=None
if cur is None:
    print("")
elif isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, (str, int, float)):
    sys.stdout.write(str(cur))
else:
    sys.stdout.write(json.dumps(cur, separators=(",", ":")))
'
      local out
      out="$(printf "%s" "$input" | "$backend" - <<PY 2>/dev/null
$py
PY
)"
      if [[ -z "$out" && -n "$default_value" ]]; then echo "$default_value"; else echo "$out"; fi
      ;;
    ruby)
      local rb
      rb='
require "json"
data = STDIN.read
begin
  obj = JSON.parse(data)
rescue
  puts ""
  exit 0
end
path = "'${path}'"
cur = obj
path.split('.').each do |seg|
  break if cur.nil?
  if cur.is_a?(Array) && seg =~ /^\d+$/
    idx = seg.to_i
    cur = (idx >= 0 && idx < cur.length) ? cur[idx] : nil
  elsif cur.is_a?(Hash)
    cur = cur[seg]
  else
    cur = nil
  end
end
if cur.nil?
  puts ""
elsif cur.is_a?(TrueClass) || cur.is_a?(FalseClass)
  puts(cur ? "true" : "false")
elsif cur.is_a?(String) || cur.is_a?(Numeric)
  print cur
else
  print JSON.generate(cur)
end
'
      local out
      out="$(printf "%s" "$input" | ruby -e "$rb" 2>/dev/null)"
      if [[ -z "$out" && -n "$default_value" ]]; then echo "$default_value"; else echo "$out"; fi
      ;;
    *)
      [[ -n "$default_value" ]] && echo "$default_value"
      ;;
  esac
}

# Преобразовать JSONL (stdin) в JSON‑массив (одна строка)
# Использование: cat transcript.jsonl | jsonl_slurp
jsonl_slurp() {
  local backend
  backend="$(_json_backend)"
  case "$backend" in
    jq)
      jq -s '.' 2>/dev/null || echo '[]'
      ;;
    powershell)
      local ps
      ps=''
      ps+='$text = [Console]::In.ReadToEnd();'
      ps+='$arr = @()'
      ps+='foreach ($line in $text -split "`r?`n") {'
      ps+='  if ([string]::IsNullOrWhiteSpace($line)) { continue }'
      ps+='  try { $obj = $line | ConvertFrom-Json -Depth 200; $arr += $obj } catch {}'
      ps+='}'
      ps+='$arr | ConvertTo-Json -Depth 200 -Compress'
      powershell -NoProfile -Command "$ps" 2>/dev/null || echo '[]'
      ;;
    python3|python)
      "$backend" - <<'PY' 2>/dev/null || echo '[]'
import sys, json
items=[]
for line in sys.stdin:
    s=line.strip()
    if not s:
        continue
    try:
        items.append(json.loads(s))
    except Exception:
        pass
sys.stdout.write(json.dumps(items, separators=(",", ":")))
PY
      ;;
    ruby)
      ruby - <<'RB' 2>/dev/null || echo '[]'
require "json"
items=[]
ARGF.each_line do |line|
  s=line.strip
  next if s.empty?
  begin
    items << JSON.parse(s)
  rescue
  end
end
print JSON.generate(items)
RB
      ;;
    *)
      echo '[]'
      ;;
  esac
}

# Вывести пары "key: value" из JSON‑объекта (stdin) — аналог jq 'to_entries[] | "\(.key): \(.value)"'
# Значения‑строки печатаются как есть, сложные — в JSON
json_to_entries() {
  local backend
  backend="$(_json_backend)"
  case "$backend" in
    jq)
      jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null
      ;;
    powershell)
      local ps
      ps=''
      ps+='$json=[Console]::In.ReadToEnd();'
      ps+='try { $obj = $json | ConvertFrom-Json -Depth 200 } catch { exit 0 }'
      ps+='if ($obj -isnot [hashtable] -and $obj -isnot [pscustomobject]) { exit 0 }'
      ps+='foreach ($p in $obj.PSObject.Properties) {'
      ps+='  $v = $p.Value'
      ps+='  if ($v -is [string]) { Write-Output ("{0}: {1}" -f $p.Name, $v) }'
      ps+='  elseif ($v -is [bool]) { Write-Output ("{0}: {1}" -f $p.Name, ($v ? "true" : "false")) }'
      ps+='  else { Write-Output ("{0}: {1}" -f $p.Name, ($v | ConvertTo-Json -Depth 200 -Compress)) }'
      ps+='}'
      powershell -NoProfile -Command "$ps" 2>/dev/null || true
      ;;
    python3|python)
      "$backend" - <<'PY' 2>/dev/null || true
import sys, json
try:
    obj=json.load(sys.stdin)
except Exception:
    sys.exit(0)
if isinstance(obj, dict):
    for k,v in obj.items():
        if isinstance(v, str):
            print(f"{k}: {v}")
        elif isinstance(v, bool):
            print(f"{k}: {'true' if v else 'false'}")
        else:
            print(f"{k}: {json.dumps(v, separators=(',', ':'))}")
PY
      ;;
    ruby)
      ruby - <<'RB' 2>/dev/null || true
require "json"
begin
  obj = JSON.parse(STDIN.read)
rescue
  exit 0
end
if obj.is_a?(Hash)
  obj.each do |k,v|
    if v.is_a?(String)
      puts "#{k}: #{v}"
    elsif v == true || v == false
      puts "#{k}: #{v ? 'true' : 'false'}"
    else
      puts "#{k}: #{JSON.generate(v)}"
    end
  end
end
RB
      ;;
    *)
      true
      ;;
  esac
}

# Сборка JSON‑объекта из пар аргументов: key value key value ... → печатает сжатый JSON
# Пример: json_build session_id "123" status "ok"
json_build() {
  if command_exists jq; then
    local args=()
    local keys=()
    local key
    local val
    while [[ $# -gt 0 ]]; do
      key="$1"; shift || true
      if [[ $# -gt 0 ]]; then
        val="$1"; shift || true
      else
        val=""
      fi
      args+=(--arg "$key" "$val")
      keys+=("$key")
    done
    jq -n -c "$(
      printf '{'
      local first=1
      local k
      for k in "${keys[@]}"; do
        if [[ $first -eq 1 ]]; then
          printf '"%s": $%s' "$k" "$k"
          first=0
        else
          printf ', "%s": $%s' "$k" "$k"
        fi
      done
      printf '}'
    )" "${args[@]}"
    return
  fi

  local backend
  backend="$(_json_backend)"
  case "$backend" in
    powershell)
      # Передаём пары как аргументы в PowerShell и собираем хеш внутри
      local ps='$h=@{}; for ($i=0; $i -lt $args.Length; $i+=2) { $k=$args[$i]; $v=($i+1 -lt $args.Length) ? $args[$i+1] : ""; $h[$k]=$v } $h | ConvertTo-Json -Depth 50 -Compress'
      powershell -NoProfile -Command "$ps" -- "$@" 2>/dev/null
      ;;
    python3|python)
      local py='import sys, json
args=sys.argv[1:]
obj={}
for i in range(0,len(args),2):
    k=args[i]
    v=args[i+1] if i+1 < len(args) else ""
    obj[k]=v
sys.stdout.write(json.dumps(obj, separators=(",", ":")))'
      "$backend" -c "$py" "$@"
      ;;
    ruby)
      ruby -e 'require "json"; h={}; ARGV.each_slice(2){|k,v| h[k]=v||""}; print JSON.generate(h)' "$@"
      ;;
    *)
      # Последний шанс — собрать как k=v пары в простую строку JSON стиля
      local out="{"
      local first=1
      while [[ $# -gt 0 ]]; do
        local k="$1"; shift; local v="$1"; shift
        if [[ $first -eq 1 ]]; then first=0; else out+=" ,"; fi
        out+="\"$k\": \"$v\""
      done
      out+="}"
      echo "$out"
      ;;
  esac
}

export -f json_get
export -f jsonl_slurp
export -f json_to_entries
export -f json_build


