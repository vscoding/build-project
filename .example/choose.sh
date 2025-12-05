#!/bin/bash

stty -echo -icanon time 0 min 0

opts=("A" "B" "C")
idx=0

draw() {
  printf "\033[H" # 光标移到左上，假设全屏使用
  for i in "${!opts[@]}"; do
    if [[ $i -eq $idx ]]; then
      printf "> %s\n" "${opts[$i]}"
    else
      printf "  %s\n" "${opts[$i]}"
    fi
  done
}

clear
draw

while true; do
  c1=$(dd bs=1 count=1 2>/dev/null)
  [[ -z $c1 ]] && continue

  if [[ $c1 == $'\e' ]]; then
    c2=$(dd bs=1 count=1 2>/dev/null)
    c3=$(dd bs=1 count=1 2>/dev/null)
    if [[ $c2 == "[" ]]; then
      case "$c3" in
        A) ((idx--)) ;; # 上
        B) ((idx++)) ;; # 下
      esac
      ((idx < 0)) && idx=0
      ((idx >= ${#opts[@]})) && idx=$((${#opts[@]} - 1))
      draw
    fi
  elif [[ $c1 == $'\n' ]]; then
    break
  fi
done

stty sane

echo "chosen: ${opts[$idx]}"
