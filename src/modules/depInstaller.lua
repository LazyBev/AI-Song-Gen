-- Dependency Installer Module
-- Handles checking and installing system dependencies

local depInstaller = {}

-- Returns the install command and package names for each package manager
function depInstaller.getInstallCommand(packageManager)
    local commands = {
        pacman = {
            cmd = "sudo pacman -S --noconfirm",
            packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
        },
        apt = {
            cmd = "sudo apt-get install -y",
            packages = {"ffmpeg", "sox", "lua5.3", "lua-filesystem"}
        },
        yum = {
            cmd = "sudo yum install -y",
            packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
        },
        dnf = {
            cmd = "sudo dnf install -y",
            packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
        },
        zypper = {
            cmd = "sudo zypper install -y",
            packages = {"ffmpeg", "sox", "lua53", "lua53-filesystem"}
        }
    }
    
    return commands[packageManager]
end

-- Checks if a command exists in the system
local function commandExists(cmd)
    return os.execute("which " .. cmd .. " > /dev/null 2>&1") == 0
end

-- Installs system dependencies if needed
function depInstaller.installDependencies()
    print("Checking system dependencies...")
    
    -- Check package managers
    local packageManagers = {"pacman", "apt", "yum", "dnf", "zypper"}
    local foundManager = nil
    
    for _, pm in ipairs(packageManagers) do
        if commandExists(pm) then
            foundManager = pm
            break
        end
    end
    
    if not foundManager then
        print("Warning: No supported package manager found. Please install dependencies manually.")
        return false
    end
    
    -- Check required commands
    local required = {"ffmpeg", "sox", "lua"}
    local missing = {}
    
    for _, cmd in ipairs(required) do
        if not commandExists(cmd) then
            table.insert(missing, cmd)
        end
    end
    
    if #missing == 0 then
        print("All dependencies are already installed.")
        return true
    end
    
    -- Install missing dependencies
    print("Installing missing dependencies using " .. foundManager .. "...")
    local cmdInfo = depInstaller.getInstallCommand(foundManager)
    if not cmdInfo then
        print("Error: Unsupported package manager: " .. foundManager)
        return false
    end
    
    local installCmd = cmdInfo.cmd .. " " .. table.concat(cmdInfo.packages, " ")
    print("Running: " .. installCmd)
    local result = os.execute(installCmd)
    
    if result == 0 then
        print("Dependencies installed successfully!")
        return true
    else
        print("Error installing dependencies. Please install them manually.")
        return false
    end
end

return depInstaller
