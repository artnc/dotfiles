-- Block overscroll: pin the last line to the bottom edge instead of letting the
-- mouse wheel scroll the buffer up into empty space, matching VSCode's
-- scrollBeyondLastLine:false and Sublime's scroll_past_end:false. micro has no
-- setting for this, so re-clamp the viewport after each downward scroll
function onScrollDown(bp)
  bp:ScrollAdjust()
  return true
end
