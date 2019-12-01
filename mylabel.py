#!/usr/bin/env python3
import signal
import os
import datetime
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, AppIndicator3, GObject
import time
from threading import Thread


user = os.environ['USER']
fileName = datetime.date.today().strftime("%Y_%m_%d.time")
filePath = "/home/"+user+"/times/"+fileName

def readMinutesLeft():
    minutesFile = open(filePath,'r')
    m = minutesFile.readline()
    minutesFile.close()
    return m

class Indicator():
    def __init__(self):
        self.app = 'test123'
        iconpath = "/opt/abouttime/icon/indicator_icon.png"
        self.indicator = AppIndicator3.Indicator.new(
            self.app, iconpath,
            AppIndicator3.IndicatorCategory.OTHER)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.create_menu())
        self.indicator.set_label("---", self.app)
        # the thread:
        self.update = Thread(target=self.show_seconds)
        # daemonize the thread to make the indicator stopable
        self.update.setDaemon(True)
        self.update.start()

    def create_menu(self):
        menu = Gtk.Menu()
        menu_sep = Gtk.SeparatorMenuItem()
        menu.append(menu_sep)
        # quit
        item_quit = Gtk.MenuItem('Quit')
        item_quit.connect('activate', self.stop)
        menu.append(item_quit)

        menu.show_all()
        return menu

    def show_seconds(self):
        while True:
            mention = str.rstrip(readMinutesLeft()) + " minutes left"
            # apply the interface update using  GObject.idle_add()
            GObject.idle_add(
                self.indicator.set_label,
                mention, self.app,
                priority=GObject.PRIORITY_DEFAULT
                )
            time.sleep(5)

    def stop(self, source):
        Gtk.main_quit()

Indicator()
# this is where we call GObject.threads_init()
GObject.threads_init()
signal.signal(signal.SIGINT, signal.SIG_DFL)
Gtk.main()
