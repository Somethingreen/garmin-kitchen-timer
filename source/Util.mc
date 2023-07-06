import Toybox.Math;

class Util {
    public static function getMinutes(time) {
        return Math.floor(time / 60);
    }

    public static function getSeconds(time) {
        return Math.floor((time - self.getMinutes(time) * 60));
    }
}