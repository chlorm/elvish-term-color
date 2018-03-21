# Copyright (c) 2018, Cody Opel <codyopel@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Methods for defining the colors used by ANSI 0-15 color codes.

local:valid-keys = [
  0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 bg fg
]

fn -validate-rgb [x]{
  for local:i [(keys $x)] {
    if (or (< $x[$i] 0) (> $x[$i] 255)) {
      fail 'Invalid RGB decimal range'
    }
  }
}

# Converts hexadecimal to decimal RGB.
fn hex-to-rgb [x]{
  if (and (!=s $x[0:1] '#') (== (count $x) 7)) {
    fail 'Got a non-hex string'
  }

  put [
    &r=(base 10 '0x'$x[1:3])
    &g=(base 10 '0x'$x[3:5])
    &b=(base 10 '0x'$x[5:7])
  ]
}

# Converts decimal to hexadecimal RGB.
fn rgb-to-hex [x]{
  -validate-rgb $x

  put '#'(base 16 $x[r])(base 16 $x[g])(base 16 $x[b])
}

fn set-gnome-terminal [x]{
  local:profile = [(dconf list /org/gnome/terminal/legacy/profiles:/)]
  # We don't have a way to differentiate profiles.
  if (!= (count $profile) 1) {
    return
  }
  profile = $profile[0]

  local:palette = []
  for local:i $valid-keys {
    local:rgb = $x[$i]

    # Allow re-assigning values. Since we only accept RGB as a map,
    # any string is assumed to be a valid key.
    if (==s (kind-of $rgb) 'string') {
      rgb = $x[$rgb]
    }

    -validate-rgb $rgb

    if (==s $i 'bg') {
      try {
        dconf write \
          '/org/gnome/terminal/legacy/profiles:/'$profile'background-color' \
          "'rgb("$rgb[r]','$rgb[g]','$rgb[b]")'"
      } except {
        fail 'dconf failed to set background-color'
      }
    } elif (==s $i 'fg') {
      try {
        dconf write \
          '/org/gnome/terminal/legacy/profiles:/'$profile'foreground-color' \
          "'rgb("$rgb[r]','$rgb[g]','$rgb[b]")'"
      } except {
        fail 'dconf failed to set foreground-color'
      }
    } else {
      palette = [ $@palette "'rgb("$rgb[r]','$rgb[g]','$rgb[b]")'" ]
    }
  }
  try {
    dconf write \
      '/org/gnome/terminal/legacy/profiles:/'$profile'palette' \
      '['(joins ', ' $palette)']'
  } except {
    fail 'dconf failed to set palette'
  }
}

fn set-x11 [x]{
  for local:i $valid-keys {
    local:rgb = $x[$i]

    # Allow re-assigning values. Since we only accept RGB as a map,
    # any string is assumed to be a valid key.
    if (==s (kind-of $rgb) 'string') {
      rgb = $x[$rgb]
    }

    -validate-rgb $rgb

    # X11 only supports hex
    local:hex = (rgb-to-hex $rgb)
    local:x11 = $hex[1:3]"/"$hex[3:5]"/"$hex[5:7]

    if (==s $i 'bg') {
      print "\033]11;rgb:"$x11"\a"
    } elif (==s $i 'fg') {
      print "\033]10;rgb:"$x11"\a"
    } else {
      print "\033]4;"$i";rgb:"$x11"\a"
    }
  }
}

fn reset-x11 {
  print "\033]104\a"
}

# Defines terminals colors used by ANSI 0-15 color codes.
# example_colors = [
#   &0=[ &r=39 &g=40 &b=34 ]
#   ...
#   &6=(hex-to-rgb '#66d9ef')
#   ...
#   &15=6
# ]
fn set [x]{
  set-x11 $x

  # TODO: Attempt to automatically set DBUS_SESSION_BUS_ADDRESS to work even
  #         when displays are not connected.
  if (and (has-env DISPLAY) (has-external gnome-terminal) (has-external dconf)) {
    set-gnome-terminal $x
  }
}
