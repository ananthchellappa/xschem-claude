# index  color      width  dash         angle  blink_ms anim        rate
set new_styles {
  {0  "#ff0000"   1   {}          0    0    none        0 }
  {1  "#00ff00"   2   {4 4}       0    0    none        0 }
  {2  "yellow"    3   {8 4 2 4}   30   0    none        0 }
  {3  "#0099cc"   2   {6 6}       45   0    none        0 }
  {4  "purple"   3   {20 20}       0   1200    none        0 }
  {5  "cyan"   3   {20 20}       30   1500    none        0 }
  {6  "orange"   3   {20 20}       30   0    march_fwd 2 }
  {7  "skyblue"   4   {16 20}       -30   0    march_rev 3 }
}

net_hilight_style_merge $new_styles

xschem update_net_hilight_style       ;# REQUIRED — the variable alone has no effect

