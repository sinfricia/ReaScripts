PLAYLIST FOLDERS FOR REAPER
----------------------------

THIS IS PRE-RELEASE SOFTWARE. THINGS MIGHT NOT WORK AS EXPECTED! IF YOU ENCOUTER ANY BUGS PLEASE REPORT THEM ON THE PROJECTS GITHUB ISSUE TRACKER:
https://github.com/sinfricia/reaper-PlaylistFolders/issues

Version: 0.4-beta
Author: Fricia


RReaScripts included in this package:

    - Copy item selection to target playlist
    - Create new playlists for selected tracks
    - Cycle down through playlists
    - Cycle up through playlists
    - Duplicate selected playlist
    - Move selected playlist to top
    - Move target playlist to top
    - Playlist functions (Collection of basic functions that the other scripts need to run)
    - Select all playlists in group with same offset to parent (runs in background)
    - Sort playlists of selected track
    - Toggle listen to playlist
    - Toggle playlist visibility for all tracks
    - Toggle playlist visibility for selected tracks



Features:

    - Create Pro Tools style playlists in Reaper.
    - Record on automatically numbered playlists, then assemble your takes on a target playlist.
    - Cycle through your playlists or move specific playlists to the top.
    - Toggle solo (listen) to specific playlists.
    - All actions (should) work with playlists hidden.
    - All actions (should) work on grouped tracks using Reapers native track grouping system. Use the "Record Arm Lead" parameter.
    - Running an action on one track will run it for all grouped tracks. Even without their playlists showing!
    - If you ever accidentally move a playlist of a grouped track or want to restore order in your playlist folders you can automatically sort them again by number.


Things to be aware of/known issues:

    - Be careful when removing playlists! You might end up with several playlists with the same number.
    - Loop recording is currently not supported.
    - In large projects with medium to high playlist counts things might get sluggish (more testing and optimization needed).
    - Since listening to a playlist currently works by soloing it, you will have to solo everything else that you want to listen to as well.



Requirements: SWS Extensions need to be installed.



These scripts are distributed without any warranty. While I plan to actively develop them further I will do so in my spare time and can't promise anything.