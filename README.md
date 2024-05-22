# lazarus-bazmon-lua
A Bazaar search and price monitoring tool for the Lazarus EQ Emulator server.

| Search | Monitor | Monitor Results|
| ------ | ------- | -------------- |
| ![Search](https://github.com/zehenforever/lazarus-bazmon-lua/blob/main/gui-search.png?raw=true) | ![Monitor](https://github.com/zehenforever/lazarus-bazmon-lua/blob/main/gui-monitor.png?raw=true) | ![Monitor Results](https://github.com/zehenforever/lazarus-bazmon-lua/blob/main/gui-monitor-results.png?raw=true) |

## Purpose and Motivation

* **In-game Bazaar Search** - The in-game Bazaar UI does not work on Lazarus, but they host a nice [Magelo Bazaar Search](https://www.lazaruseq.com/Magelo/index.php?page=bazaar) web app. BazMon provides in-game searches for the Bazaar by querying the Magelo site in the background.

    _I.e., we have reproduced the Magelo Bazaar search interface in game._

* **In-game Bazaar Price Monitoring** - You can now automatically monitor the Bazaar for a custom set of items and prices, and be notified if any items show up in the Bazaar that meet your criteria.

    _E.g., you can be notified if any "Fabled Earthshaker" appear in the Bazaar for less than 60,000pp._

The EQ Bazaar interface does not work on Lazarus, so people use the hosted Magelo web site (https://www.lazaruseq.com/Magelo/index.php?page=bazaar) instead. That is a great tool and a fine option.

This tool exists for enable searching the Bazaar from within the game.

## Features
* **Search** 
  * Search for any item by name, including partial matches
  * Search based on Class, Race, Slot, Stat, item Type, Aug type
  * Set a minimum or maximum price
  * Sort results by item name, Ascending or Descending
* **Monitor**
  * Configure a set of items to monitor by Item Name, a Comparison (i.e., "Less than or equal to" or "Greater than or equal to"), and a Price.
* **Monitor Results**
  * Receive in game notifications when new matching items are discovered in the Bazaar.
  * View a list of items currently in the Bazaar that match your set of items being monitored. 

## How it works
We need to set up two scripts, one for the front end, and one for the back end:

1. **Front end (this repo)**: A normal Lua script that is run by MQ's `/lua run <script>` functionality.  It presents the UI and writes its data to a standard INI file just like any other plugin.  It also reads query result data from two separate CSV files that are populated by the backend server.
1. **Back end**: A standard Go program ([at this repo](https://github.com/ZehenForever/lazarus-bazmon-server)) that watches for changes in the INI file containing new search and monitor requests. It then constructs an HTTP search of the Lazarus Magelo Bazaar web site, parses the web page results, and writes them to the CSV file. This CSV file is watched by the frontend Lua script, and it displays any matching search results in the UI.

> [!NOTE]
> See the [Architecutre](#Architecture) section below to a visual diagram on how this works.

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

> [!IMPORTANT]
> Be sure to use the name of the folder you cloned or extracted to when attempting to `/lua run <your_folder_name>`

This will launch the UI which is pretty self explanatory.


### Set up the backend
Setting up and using the the backend Go program can be found in [its repository](https://github.com/ZehenForever/lazarus-bazmon-server).

## Basic Control Flow

### Searching
1. Be sure to click the "Search" tab at the top of the UI.
1. Fill out your search criteria using various text/number inputs and various dropdowns.
1. When you click the "Search" button, it will record that query request into its `BazMon.ini` ini file.
1. If the backend server is running, it will see this file change, will parse out the query from the .ini file, and run a query agains the Lazarus Magelo Bazaar page.
1. The backend server will then parse those Bazaar search results and write them to the `BazMon_SearchResults.csv` file.
1. The front end will poll that file until a configurable timeout (currently 5 seconds), and once there are matching results in the CSV, it will paint those in game in the UI as a table of search results.

### Monitoring
1. Be sure to click the "Monitor" tab at the top of the UI to configure items to monitor.
1. Choose an item Name, Price, and a Comparison ("Less than or equal to", "Greater than or equal to").
1. When you click the "Save" button, it will write those entries to the `[Monitor]` section of the INI file.
1. If the backend server is running, it will see this file change and will parse out the items to monitor and add that to its own internal list.
1. The backend will periodically check the Bazaar for any matching entries and will write them to the `BazMon_MonitorResults.csv` file.
1. The front end will poll this file to look for new changes and both display them in game and provide an in-game notification.

## Architecture

![architecture](https://github.com/zehenforever/lazarus-bazmon-lua/blob/main/architecture.png?raw=true)
