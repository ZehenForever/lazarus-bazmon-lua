# lazarus-bazmon-lua
A Bazaar search tool Lua script for the Lazarus EQ Emulator server

## Motivation
The EQ Bazaar interface does not work on Lazarus, so people use the hosted Magelo web site (https://www.lazaruseq.com/Magelo/index.php?page=bazaar) instead. That is a great tool and a fine option.

This tool exists for enable searching the Bazaar from within the game.

## How it works
This is achieved by running two scripts:

1. **Front end**: A normal Lua script (this repo) that is run by MQ's `/lua run <script>` functionality.  It presents the UI and writes its data to a standard .ini file just like any other plugin.  It reads query result data from a separate CSV file populated by the backend server.
1. **Back end**: A standard Go program ([found here](https://github.com/ZehenForever/lazarus-bazmon-server)) that watches for changes in the Lua .ini file and uses that to essentially proxy queries to the Lazarus Magelo Bazaar search page.  It writes query results to a CSV file that can be in turn read by the Lua script to show those search results in game.

## Usage

### Set up the front end (this)

Either [download the zip](https://github.com/ZehenForever/lazarus-bazmon-lua/archive/refs/heads/main.zip) from Github and unzip it alongside your other Lua scripts, or clone the repo to your Lua scripts directory:

```
cd C:\PathToE3MQ\lua
git clone git@github.com:ZehenForever/lazarus-bazmon-lua.git bazmon
```

Run the Lua script in game:
```
/lua run bazmon
```

[!NOTE]
Be sure to use the name of the folder you cloned or extracted to when attempting to `/lua run <your_folder_name>`

This will launch the UI which is pretty self explanatory.

The basic flow is:
1. When you click the "Search" button, it will record that query request into its `BazMon.ini` ini file.
1. If the backend server is running, it will see this file change, will parse out the query from the .ini file, and run a query agains the Lazarus Magelo Bazaar page.
1. The backend server will then parse those Bazaar search results and write them to the `BazResults.csv` file.
1. The front end will poll that file until a configurable timeout (currently 5 seconds), and once there are matching results in the CSV, it will paint those in game in the UI as a table of search results.

### Set up the backend
Setting up and using the the backend Go program can be found in [its repository](https://github.com/ZehenForever/lazarus-bazmon-server).
