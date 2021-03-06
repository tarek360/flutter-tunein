import 'dart:async';
import 'dart:io';

import 'package:Tunein/globals.dart';
import 'package:Tunein/models/playback.dart';
import 'package:Tunein/models/playerstate.dart';
import 'package:Tunein/plugins/nano.dart';
import 'package:Tunein/services/themeService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_notification/media_notification.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'locator.dart';

final themeService = locator<ThemeService>();


enum SettingsIds{
  SET_LANG,
  SET_ARTIST_THUMB_UPDATE
}


class settingService{

  BehaviorSubject<Map<SettingsIds,String>> _settings$;


  BehaviorSubject<Map<SettingsIds, String>> get settings$ => _settings$;


  settingService(){
    _initStreams();
  }

  _initStreams(){
    _settings$ = BehaviorSubject<Map<SettingsIds,String>>();
  }


  fetchSettings() async{
    Map<SettingsIds, String> settingsMap = new Map();
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    try{
      SettingsIds.values.toList().forEach((setting){
        settingsMap[setting] = _prefs.getString(getEnumValue(setting).toString());
      });
    }catch (e){
      return false;
    }
    _settings$.add(settingsMap);
  }


  fetchSingleSetting(SettingsIds setting)async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    try{
      Map<SettingsIds, String> settingsMap = _settings$.value;
      settingsMap[setting]= _prefs.getString(getEnumValue(setting).toString());
      _settings$.add(settingsMap);
    }catch (e){
      print("Error in fetching setting ${e}");
      return false;
    }
  }

  updateSingleSetting(SettingsIds setting, String value) async{
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    try{
      Map<SettingsIds, String> settingsMap = _settings$.value;
      await _prefs.setString(getEnumValue(setting).toString(),value);
      settingsMap[setting]= value;
      _settings$.add(settingsMap);
    }catch (e){
      print("Error in saving setting ${e}");
      return false;
    }
  }



  //Utils

  String getEnumValue(SettingsIds set){
    return set.toString().split('.').last;
  }

  void dispose() {
    _settings$.close();
  }
}

