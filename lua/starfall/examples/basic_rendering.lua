--@name Basic Rendering
--@author Vurv
--@client

-- You should only create a font once, (absolutely not inside of a render hook)
local font = render.createFont("Default", 30)

-- Create the color outside of the render hook to avoid wasting cpu time
-- This works based on a 0-255 (byte) scale, and alpha is by default 255 (opaque)
local textColor = Color(255, 0, 0)

-- This creates a "hook" which calls the function to draw on the screen every frame.
-- You can only perform rendering operations inside of a render hook.

-- The second argument to hook.add is just the name of the hook
-- It can be named anything, as long as they don't overlap.
-- You use the name if you want to remove the hook later.
-- Otherwise, you can just name it something easy like "".
hook.add("render", "", function()
	render.setColor(textColor)
	render.setFont(font)

	-- Draw text at (20, 20) from the top left corner of the screen
	render.drawText(20, 20, "Hello World!")
end)
