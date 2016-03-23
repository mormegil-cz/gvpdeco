GVP Voicepack Decompiler (GVPDeco)
**********************************
Version 1.1, Copyright (C) 2002, Petr Kadlec <mormegil@centrum.cz>

General
=======
This program may be used to decompile any GVP Voicepack file used in Microsoft Flight Simulator 2002, no matter if it is original or created using the Voicepack SDK.
The program reads a voicepack file and creates a configuration file and a phrase file, which can be used to re-compile the voicepack using VPEdit from the Voicepack SDK, and it also extracts all WAV files used in the voicepack. So that you should be able to recompile the GVP using VPEdit immediately after decompiling it. (Please note: The resulting file may not be exactly identical to the source voicepack file. This is mainly because the decompiler rearranges the order of the phrases.)

Usage
=====
If you start the program as it is, it will display three dialog boxes. In the first, you select the GVP voicepack file which you want to decompile. In the second, you should choose a filename for the XML project file which will be created by the program. In the last dialog, you choose a filename for the TXT phrase file which will also be created by the decompiler. (Note: The folders with the sound files will be created in the folder that contains the created TXT file selected in the last dialog.)
As an alternative, you may give all required filenames on the command line, using the following command:

DecompileGVP [options] SourceFile.gvp ConfigFile.xml PhraseFile.txt

Where SourceFile.gvp is the voicepack you want to decompile, ConfigFile.xml is the name of the XML configuration file that will be created by the decompiler and PhraseFile.txt is the name of the TXT phrase file that will be created by the decompiler.
The folders with the sound files will be created in the current folder.
You may use the following additional parameters to alter the program behaviour:

-o directory Change the "Output" directory which is stored in the XML configuration file. If you do not use this parameter, the default value "Output" will be used.

-f directory Change the name of the directory, in which are the wave files stored. If you do not use this parameter, the default value "WAV" will be used.

-n Tells the program not to extract the wave files. Only the XML configuration file and TXT phrase file will be created.

-w Tells the program not to overwrite any existing wave file. If the voicepack contains two ambiguous sound identifiers, the wave files will have the same names and will overwrite each other. If you supply -w, the program will exit with an error, when a wave file already exists.

Example:
  DecompileGVP -o ASOSOutput -n USEnglishASOS.gvp ASOS.xml ASOSPhrases.txt

Bugs
====
Although the program has been tested a bit, it is almost certain that it contains some errors. If you find any, please let me know about it.

Contact
=======
The author may be contacted by e-mail at mormegil@centrum.cz.

Legal information
=================
If you decompile voicepack created by another author (such as the original voicepacks supplied with MSFS), you may be violating copyright laws. The author can not be held responsible for what you are doing with the program!

This program is distributed under conditions of the GNU license. See gnu_license.txt (or gnu_licence_cz.txt, you may choose which language version you prefer) for more information.

The names of actual companies and products mentioned herein may be the trademarks of their respective owners.

Files in the distribution
=========================
 DecompileGVP.exe   The main executable program. 77824 bytes, MD5 digest=98D0FB591CBE59119CE97C856C14D8E2
 gnu_license.txt    The GNU general public license under which is the program distributed.
 gnu_licence_cz.txt The GNU license in the czech translation. You may choose which language version of the license you want to be bound by.
 readme.txt         This documentation.
 source.zip         Source code for the program, written in Borland Delphi 5. This file is not required for normal usage of the program and you may delete it if you want.

Version history
===============
1.1 This version, added dialog boxes as an alternative to command line parameters.
1.0 Initial release.
