import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Application;
import Toybox.System;

const MODE_MINUTES = 1;
const MODE_SECONDS = 2;
const MODE_COUNTDOWN = 3;
const MODE_PAUSED = 4;

const MINUTES_MAX = 99;
const SECONDS_MAX = 55;
const SECONDS_STEP = 5;
const SECONDS_TO_TAP = 5;

const STORAGE_COUNTDOWN = "countdown";

class KitchenTimerView extends WatchUi.View {
    private var _mode = MODE_MINUTES;
    private var _minutes = 0 as Number;
    private var _seconds = 0 as Number;
    private var _layoutSet = false;
    private var _minuteControls = null as Drawable;
    private var _secondControls = null as Drawable;
    private var _time = null as Text;

    public function initialize() {
        View.initialize();
    }

    public function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
        _layoutSet = true;
        _minuteControls = View.findDrawableById("MinuteControls");
        _secondControls = View.findDrawableById("SecondControls");
        _time = View.findDrawableById("time") as Text;
        setMode(_mode);
    }

    public function onUpdate(dc as Dc) as Void {
        var timeString = Lang.format("$1$:$2$", [_minutes.format("%02d"), _seconds.format("%02d")]);
        _time.setText(timeString);
        View.onUpdate(dc);
    }

    public function onShow() as Void {
        //pushView(new TimerPicker(), new TimerPickerDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    public function onHide() as Void {
    }

    public function setTime(time as Number) {
        _minutes = Util.getMinutes(time);
        _seconds = Util.getSeconds(time);
    }

    public function setMode(mode) {
        if (!_layoutSet) {
            _mode = mode;
            return;
        }
        
        switch (mode) {
            case MODE_MINUTES:
                _minuteControls.setVisible(true);
                _secondControls.setVisible(false);
                _time.setColor(Graphics.COLOR_WHITE);
                break;
            case MODE_SECONDS:
                _minuteControls.setVisible(false);
                _secondControls.setVisible(true);
                _time.setColor(Graphics.COLOR_WHITE);
                break;
            case MODE_COUNTDOWN:
                _minuteControls.setVisible(false);
                _secondControls.setVisible(false);
                _time.setColor(Graphics.COLOR_WHITE);
                break;
            case MODE_PAUSED:
                _minuteControls.setVisible(false);
                _secondControls.setVisible(false);
                _time.setColor(Graphics.COLOR_LT_GRAY);
                break;
        }
        WatchUi.requestUpdate();
    }
}

class KitchenTimerViewDelegate extends WatchUi.BehaviorDelegate {
    private var _view;
    private var _mode = MODE_MINUTES;
    private var _countdownTime = 0;
    private var _remainingTime;
    private var _timer;
    private var _exitConfirmation;

    public function initialize(view) {
        _view = view;
        _timer = new Timer.Timer();
        _exitConfirmation = WatchUi.loadResource(Rez.Strings.confirmationExit) as String;

        _countdownTime = loadCountdownTime();
        if (_countdownTime > 0) {
            _mode = MODE_SECONDS;
        }

        _view.setMode(_mode);
        updateTimeView(_countdownTime);
        BehaviorDelegate.initialize();
    }

    public function onSelect() {
        switch (_mode) {
            case MODE_MINUTES:
                _mode = MODE_SECONDS;
                _view.setMode(_mode);
                break;
            case MODE_SECONDS:
                if (_countdownTime > 0) {
                    _mode = MODE_COUNTDOWN;
                    _view.setMode(_mode);
                    _remainingTime = _countdownTime;
                    updateTimeView(_remainingTime);
                    _timer.start(method(:onTimer), 1000, true);
                }
                break;
            case MODE_COUNTDOWN:
                _mode = MODE_PAUSED;
                _view.setMode(_mode);
                _timer.stop();
                break;
            case MODE_PAUSED:
                _mode = MODE_COUNTDOWN;
                _view.setMode(_mode);
                _timer.start(method(:onTimer), 1000, true);
                break;
        }
        return true;
    }

    public function onNextPage() {
        switch (_mode) {
            case MODE_MINUTES:
                if (_countdownTime >= 60) {
                    _countdownTime -= 60;
                } else {
                    _countdownTime = MINUTES_MAX * 60 + _countdownTime;
                }
                saveCountdownTime(_countdownTime);
                updateTimeView(_countdownTime);
                break;
            case MODE_SECONDS:
                if (Util.getSeconds(_countdownTime) > 0) {
                    _countdownTime -= SECONDS_STEP;
                } else {
                    _countdownTime += SECONDS_MAX;
                }
                saveCountdownTime(_countdownTime);
                updateTimeView(_countdownTime);
                break;
        }
        return true;
    }

    public function onPreviousPage() {
        switch (_mode) {
            case MODE_MINUTES:
                if (_countdownTime >= MINUTES_MAX * 60) {
                    _countdownTime = Util.getSeconds(_countdownTime);
                } else {
                    _countdownTime += 60;
                }
                saveCountdownTime(_countdownTime);
                updateTimeView(_countdownTime);
                break;
            case MODE_SECONDS:
                if (Util.getSeconds(_countdownTime) == SECONDS_MAX) {
                    _countdownTime -= SECONDS_MAX;
                } else {
                    _countdownTime += SECONDS_STEP;
                }
                saveCountdownTime(_countdownTime);
                updateTimeView(_countdownTime);
                break;
        }
        return true;
    }

    public function onBack() {
        switch (_mode) {
            case MODE_SECONDS:
                _mode = MODE_MINUTES;
                _view.setMode(_mode);
                break;
            case MODE_PAUSED:
                reset();
                break;
            case MODE_MINUTES:
                WatchUi.pushView(
                    new WatchUi.Confirmation(_exitConfirmation), 
                    new ExitConfirmationDelegate(), 
                    WatchUi.SLIDE_IMMEDIATE);
                break;
        }
        return true;
    }

    public function onTimer() as Void {
        _remainingTime -= 1;
        updateTimeView(_remainingTime);
        if (_remainingTime <= SECONDS_TO_TAP && _remainingTime > 0) {
            Attention.vibrate([new Attention.VibeProfile(50, 50)]);
        } else if (_remainingTime <= 0) {
            _timer.stop();
            Attention.vibrate([
                new Attention.VibeProfile(50, 500),
                new Attention.VibeProfile(0, 250),
                new Attention.VibeProfile(50, 500),
                new Attention.VibeProfile(0, 250),
                new Attention.VibeProfile(50, 500)
            ]);
            reset();
        }
    }

    private function loadCountdownTime() as Number {
        var countdownTime = Application.Storage.getValue(STORAGE_COUNTDOWN);
        if (countdownTime == null) {
            countdownTime = 0;
        }
        return countdownTime;
    }

    private function saveCountdownTime(countdownTime as Number) {
        Application.Storage.setValue(STORAGE_COUNTDOWN, countdownTime);
    }

    private function updateTimeView(time) {
        _view.setTime(time);
        WatchUi.requestUpdate();
    }

    private function reset() {
        _mode = MODE_SECONDS;
        _view.setMode(_mode);
        updateTimeView(_countdownTime);
    }
}

class ExitConfirmationDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            System.exit();
        }
        return true;
    }
}