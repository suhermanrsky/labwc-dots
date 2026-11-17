#!/bin/bash

#####################################
## author @Harsh-bin Github #########
#####################################

# Configuration
config_dir="$HOME/.config/rofi/clipboard"
clip_theme="$config_dir/clipboard.rasi"
clip_img_theme="$config_dir/clipboard_img.rasi"
confirm_theme="$config_dir/confirmation.rasi"
# Database files
text_db="$config_dir/text.db"
img_db="$config_dir/image.db"
pinned_file="$config_dir/pinned.txt"
wipe_flag="$config_dir/.wipe_pending" 
touch "$pinned_file" 
text_db="$config_dir/text.db"
img_db="$config_dir/image.db"
pinned_file="$config_dir/pinned.txt"
pinned_img_dir="$config_dir/pinned_images"
wipe_flag="$config_dir/.wipe_pending" 
mkdir -p "$pinned_img_dir" 
touch "$pinned_file" 

copy_pinned_item() {
  local item="$1"
  if [[ "$item" == IMG:* ]]; then
    local img_path="${item#IMG:}"
    if [[ -f "$img_path" ]]; then
      wl-copy < "$img_path"
      notify-send "Clipboard Manager" "Pinned image copied to clipboard" --icon="$img_path"
    else
      notify-send "Clipboard Manager" "Pinned image file not found!"
    fi
  else
    echo -n "$item" | wl-copy
    wtype -M ctrl -M shift -P v -s 500 -p v -m shift -m ctrl
    notify-send "Clipboard Manager" "Pinned text copied to clipboard"
  fi
}

remove_pinned_line() {
  local line_num="$1"
  local content
  content=$(sed -n "${line_num}p" "$pinned_file")
  if [[ "$content" == IMG:* ]]; then
    local img_to_del="${content#IMG:}"
    if [[ -f "$img_to_del" ]]; then
      cliphist -db-path "$img_db" store < "$img_to_del"
      rm -f "$img_to_del"
    fi
  elif [[ -n "$content" ]]; then
    printf '%s' "$content" | cliphist -db-path "$text_db" store
  fi
  sed -i "${line_num}d" "$pinned_file"
}

manage_pinned() {
  options="  View Pinned Items\n  Pin Image from History\n  Pin from History\n  Unpin Item\n  Batch Pin from History\n  Batch Unpin Items"
  choice=$(printf '%b' "$options" | rofi -dmenu -p "Pinned" -theme "$clip_theme")

  case "$choice" in
  *"View Pinned Items"*)
    if [[ ! -s "$pinned_file" ]]; then
      notify-send "Clipboard Manager" "No clipboard getting pinned"
      return
    fi
    selected_idx=$(
      while IFS= read -r line; do
        if [[ "$line" == IMG:* ]]; then
          img_path="${line#IMG:}"
          printf '  %s\0icon\x1f%s\n' "$(basename "$img_path")" "$img_path"
        else
          printf '  %s\n' "$line"
        fi
      done < "$pinned_file" | rofi -dmenu -format i -p "Select Pinned" -theme "$clip_theme"
    )
    if [[ -n "$selected_idx" && "$selected_idx" =~ ^[0-9]+$ ]]; then
      target_line=$((selected_idx + 1))
      raw_item=$(sed -n "${target_line}p" "$pinned_file")
      copy_pinned_item "$raw_item"
    fi
    ;;
  *"Pin Image from History"*)
    img_choice=$(${config_dir}/cliphist_rofi_img | rofi -dmenu -theme "$clip_img_theme")
    if [[ -n "$img_choice" ]]; then
      saved_img="$pinned_img_dir/pin_$(date +%s%N).png"
      echo "$img_choice" | cliphist -db-path "$img_db" decode > "$saved_img"
      if [[ -s "$saved_img" ]]; then
        echo "IMG:$saved_img" >> "$pinned_file"
        rm -f "$wipe_flag"
        notify-send "Clipboard Manager" "Image pinned successfully!" --icon="$saved_img"
      else
        rm -f "$saved_img"
      fi
    fi
    ;;
  *"Batch Pin from History"*)
    to_pins=$(cliphist -db-path "$text_db" list | rofi -dmenu -multi-select -display-columns 2 \
      -theme-str 'entry{placeholder: " Search\t[Shift + Enter for multiple pin]";}' \
      -theme "$clip_theme")

    if [[ -n "$to_pins" ]]; then
      count=0
      while IFS= read -r item; do
        if [[ -n "$item" ]]; then
          decoded_text=$(cliphist -db-path "$text_db" decode "$item")
          clean_text=$(echo "$decoded_text" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -n "$clean_text" ]]; then
            echo "$clean_text" >> "$pinned_file"
            ((count++))
          fi
        fi
      done <<< "$to_pins"

      if [[ $count -gt 0 ]]; then
        rm -f "$wipe_flag"
        notify-send "Clipboard Manager" "$count items pinned successfully!"
      fi
    fi
    ;;
  *"Pin from History"*)
    to_pin=$(cliphist -db-path "$text_db" list | rofi -dmenu -display-columns 2 -theme "$clip_theme")
    if [[ -n "$to_pin" ]]; then
      decoded_text=$(cliphist -db-path "$text_db" decode "$to_pin")
      clean_text=$(echo "$decoded_text" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -n "$clean_text" ]]; then
        echo "$clean_text" >> "$pinned_file"
        rm -f "$wipe_flag"
        notify-send "Clipboard Manager" "Pinned success!"
      fi
    fi
    ;;
  *"Batch Unpin Items"*)
    if [[ ! -s "$pinned_file" ]]; then
      notify-send "Clipboard Manager" "Pin empty"
      return
    fi
    line_indices=$(
      while IFS= read -r line; do
        if [[ "$line" == IMG:* ]]; then
          img_path="${line#IMG:}"
          printf '  %s\0icon\x1f%s\n' "$(basename "$img_path")" "$img_path"
        else
          printf '  %s\n' "$line"
        fi
      done < "$pinned_file" | rofi -dmenu -multi-select -format i \
        -theme-str 'entry{placeholder: " Search\t[Shift + Enter for multiple unpin]";}' \
        -theme "$clip_theme"
    )

    if [[ -n "$line_indices" ]]; then
      sorted_lines=$(echo "$line_indices" | sort -rn)
      while IFS= read -r idx; do
        if [[ -n "$idx" && "$idx" =~ ^[0-9]+$ ]]; then
          remove_pinned_line $((idx + 1))
        fi
      done <<< "$sorted_lines"
      notify-send "Clipboard Manager" "Selected pinned items deleted"
    fi
    ;;
  *"Unpin Item"*)
    if [[ ! -s "$pinned_file" ]]; then
      notify-send "Clipboard Manager" "Pin empty"
      return
    fi
    line_idx=$(
      while IFS= read -r line; do
        if [[ "$line" == IMG:* ]]; then
          img_path="${line#IMG:}"
          printf '  %s\0icon\x1f%s\n' "$(basename "$img_path")" "$img_path"
        else
          printf '  %s\n' "$line"
        fi
      done < "$pinned_file" | rofi -dmenu -format i -p "Remove Pin" -theme "$clip_theme"
    )
    if [[ -n "$line_idx" && "$line_idx" =~ ^[0-9]+$ ]]; then
      remove_pinned_line $((line_idx + 1))
      notify-send "Clipboard Manager" "Pinned item deleted"
    fi
    ;;
  esac
}

image_history() {
  img_choice=$(${config_dir}/cliphist_rofi_img | rofi -dmenu -theme "$clip_img_theme")
  if [[ -n "$img_choice" ]]; then
    tmp_img="/tmp/clipboard.png"
    echo "$img_choice" | cliphist -db-path "$img_db" decode >"$tmp_img"
    options="Copy Image\nPin Image\nOpen Image\nExport"
    choice=$(echo -e "$options" | rofi -dmenu \
      -mesg $'<big><b>Clipboard</b></big>\nWhat would you like to do?' \
      -theme "$confirm_theme")

    case "$choice" in
    "Copy Image")
      wl-copy <"$tmp_img"
      notify-send "Clipboard Manager" "Image copied to clipboard" --icon="$tmp_img"
      sleep 1
      rm "$tmp_img"
      ;;
    "Pin Image")
      saved_img="$pinned_img_dir/pin_$(date +%s%N).png"
      mv "$tmp_img" "$saved_img"
      echo "IMG:$saved_img" >> "$pinned_file"
      rm -f "$wipe_flag"
      notify-send "Clipboard Manager" "Image pinned!" --icon="$saved_img"
      ;;
    "Open Image")
      # Extract background color for feh window
      labwc_theme="$HOME/.config/labwc/themerc-override"
      bg_color=$(awk '/^window.active.title.bg.color:/ {print $2}' "$labwc_theme")
      # Open the image
      if command -v feh >/dev/null 2>&1; then
        feh --image-bg "${bg_color:-#000000}" --scale-down "$tmp_img"
      else
        xdg-open "$tmp_img"
      fi
      sleep 1
      rm "$tmp_img"
      ;;
    "Export")
      export_dir="$HOME/Pictures/clipboard"
      mkdir -p "$export_dir"
      file_path="$export_dir/$(date +%s).png"
      mv "$tmp_img" "$file_path"
      notify-send "Clipboard Manager" "Image Exported\nPath: ${file_path/$HOME/\~}" --icon="$file_path"
      ;;
    *)
      notify-send "Clipboard Manager" "canceled"
      rm "$tmp_img"
      ;;
    esac
  fi
}

wipe_clipboard() {
  options="Everything\nAll Text\nAll Images"
  # Show the menu
  choice=$(echo -e "$options" | rofi -dmenu \
    -mesg $'<big><b>Wipe Clipboard</b></big>\nWhat would you like to clear?' \
    -theme "$confirm_theme")

  case "$choice" in
  "Everything")
    cliphist -db-path "$text_db" wipe
    cliphist -db-path "$img_db" wipe
    wl-copy -c
    notify-send "Clipboard Manager" "History wiped (Pinned items kept)"
    ;;
  "All Text")
    cliphist -db-path "$text_db" wipe
    notify-send "Clipboard Manager" "All text entries deleted"
    ;;
  "All Images")
    cliphist -db-path "$img_db" wipe
    notify-send "Clipboard Manager" "All image entries deleted"
    ;;
  *)
    notify-send "Clipboard Manager" "Wipe canceled"
    ;;
  esac
}

delete_images() {
  # Opens the same cliphist_rofi_img list but with multi-select enabled
  img_selections=$(${config_dir}/cliphist_rofi_img | rofi -dmenu -multi-select \
    -theme-str 'element-text { enabled: true; font: "sans 10"; padding: 5px; }' \
    -theme "$clip_img_theme")

  if [[ -n "$img_selections" ]]; then
    confirmation=$(echo -e "Yes\nNo" |
      rofi -dmenu \
        -mesg $'<big><b>Delete Images Confirmation</b></big>\nAre you sure you want to delete selected images?' \
        -theme "$confirm_theme")

    if [[ $confirmation == "Yes" ]]; then
      # Delete selected images from image database
      echo "$img_selections" | cliphist -db-path "$img_db" delete
      notify-send "Clipboard Manager" "Selected images deleted"
    else
      notify-send "Clipboard Manager" "Image deletion canceled"
    fi
  fi
}

delete_items() {
  # Run rofi with -multi-select and added "Delete Image History" option at the top
  selections=$(
    {
      printf '\t\uf03e  Delete Image History\n'
      cliphist -db-path "$text_db" list
    } | rofi -dmenu -multi-select -display-columns 2 \
      -theme-str 'entry{placeholder: " Search\t[Shift + Enter for multiple selection]";}' \
      -theme "$clip_theme"
  )

  # If nothing else was selected, exit the function
  if [[ -z "$selections" ]]; then
    return
  fi

  if [[ -n "$selections" ]]; then
    # Check if "Delete Image History" was one of the selected items
    if [[ "$selections" == *"Delete Image History"* ]]; then
      selection_count=$(echo "$selections" | grep -c .)
      if [[ "$selection_count" -eq 1 ]]; then
        # Only one item selected and it is the delete option
        delete_images
        return
      else
        # Multiple items selected; remove "Delete Image History"
        selections=$(echo "$selections" | grep -v "Delete Image History")
      fi
    fi

    # Process standard text/clipboard items
    confirmation=$(echo -e "Yes\nNo" |
      rofi -dmenu \
        -mesg $'<big><b>Delete Items Confirmation</b></big>\nAre you sure you want to delete selected items?' \
        -theme "$confirm_theme")

    if [[ $confirmation == "Yes" ]]; then
      # Delete selected items
      echo "$selections" | cliphist -db-path "$text_db" delete
      notify-send "Clipboard Manager" "Selected items deleted"
    else
      notify-send "Clipboard Manager" "Deletion canceled"
    fi
  fi
}

handle_text_selection() {
  local selection="$1"
  cliphist -db-path "$text_db" decode "$selection" | wl-copy
  wtype -M ctrl -M shift -P v -s 500 -p v -m shift -m ctrl
  notify-send "Clipboard Manager" "Text copied to clipboard"
}

# Generates clipboard main menu
clipboard=$(
  {
    printf '\t\uf08d  Pinned\n'
    printf '\t\uf03e  Image History\n'
    printf '\t\uf2ed  Batch Delete\n'
    printf '\t\uf1f8  Wipe Clipboard\n'
    if [[ -s "$pinned_file" ]]; then
      while IFS= read -r line; do
        if [[ "$line" == IMG:* ]]; then
          img_path="${line#IMG:}"
          printf '\t\uf02e  %s\0icon\x1f%s\n' "$(basename "$img_path")" "$img_path"
        elif [[ -n "$line" ]]; then
          printf '\t\uf02e  %s\n' "$line"
        fi
      done < "$pinned_file"
    fi
    cliphist -db-path "$text_db" list
  } | rofi -dmenu -display-columns 2 -theme "$clip_theme"
)

# Handle Selection
if [[ $clipboard == *"Pinned"* ]]; then
  manage_pinned
  exit
elif [[ $clipboard == *"Image History"* ]]; then
  image_history
  exit
elif [[ $clipboard == *"Batch Delete"* ]]; then
  delete_items
  exit
elif [[ $clipboard == *"Wipe Clipboard"* ]]; then
  wipe_clipboard
  exit
elif [[ $clipboard == $'\uf02e  '* ]]; then
  item_name="${clipboard#$'\uf02e  '}"
  if [[ -f "$pinned_img_dir/$item_name" ]]; then
    copy_pinned_item "IMG:$pinned_img_dir/$item_name"
  else
    copy_pinned_item "$item_name"
  fi
  exit
elif [[ -n $clipboard ]]; then
  handle_text_selection "$clipboard"
else
  exit
fi
