-- Main entry point for the AI Song Maker application
-- This is the only file that should be executed directly

-- Load dependencies
local depInstaller = require("modules.depInstaller")
local menu = require("modules.menu")

-- Main function
local function main()
    print("╔════════════════════════════════════════════════════════════╗")
    print("║           AI SONG MAKER - Full Pipeline                    ║")
    print("╚════════════════════════════════════════════════════════════╝\n")

    -- Check and install dependencies if needed
    if not depInstaller.installDependencies() then
        print("Error: Failed to install required dependencies.")
        return 1
    end

    -- Start the interactive menu
    menu.interactiveMenu()
    
    return 0
end

-- Run the application
local status, err = pcall(main)
if not status then
    print("Error: " .. tostring(err))
    os.exit(1)
end

os.exit(0)
