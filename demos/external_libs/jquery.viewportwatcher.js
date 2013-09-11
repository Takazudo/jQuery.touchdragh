/*! jQuery.viewportWatcher (https://github.com/Takazudo/jQuery.viewportWatcher)
 * lastupdate: 2013-09-11
 * version: 0.2.0
 * author: 'Takazudo' Takeshi Takatsudo <takazudo@gmail.com>
 * License: MIT */
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  (function($) {
    var $window, EveEve, ns, viewportSize;
    $window = $(window);
    viewportSize = window.viewportSize;
    EveEve = window.EveEve;
    ns = {};
    ns.viewport = {};
    ns.viewport.width = function() {
      return viewportSize.getWidth();
    };
    ns.viewport.height = function() {
      return viewportSize.getHeight();
    };
    ns.limit = function(func, wait, debounce) {
      var timeout;
      timeout = null;
      return function() {
        var args, context, throttler;
        context = this;
        args = arguments;
        throttler = function() {
          timeout = null;
          return func.apply(context, args);
        };
        if (debounce) {
          clearTimeout(timeout);
        }
        if (debounce || !timeout) {
          return timeout = setTimeout(throttler, wait);
        }
      };
    };
    ns.throttle = function(func, wait) {
      return ns.limit(func, wait, false);
    };
    ns.debounce = function(func, wait) {
      return ns.limit(func, wait, true);
    };
    ns.WinWatcher = (function(_super) {
      var eventNames;

      __extends(WinWatcher, _super);

      eventNames = 'resize orientationchange';

      function WinWatcher() {
        var _this = this;
        $window.bind(eventNames, function() {
          return _this.trigger('resize');
        });
      }

      return WinWatcher;

    })(EveEve);
    ns.winWatcher = new ns.WinWatcher;
    ns.Observation = (function() {
      function Observation(criteria, handlers) {
        this.criteria = criteria;
        this.handlers = handlers;
        this._handlerFired = false;
        this.active = false;
      }

      Observation.prototype.handleNotification = function(info) {
        if ((this._shouldIHandle(info)) && (!this._handlerFired)) {
          this.handlers.match();
          this.active = true;
          this._handlerFired = true;
          return true;
        } else {
          return false;
        }
      };

      Observation.prototype.resetFiredFlag = function() {
        return this._handlerFired = false;
      };

      Observation.prototype._shouldIHandle = function(info) {
        return this.criteria(info.width);
      };

      return Observation;

    })();
    ns.Watcher = (function(_super) {
      __extends(Watcher, _super);

      Watcher.defaults = {
        notify_on_init: true,
        throttle_millisec: 200
      };

      function Watcher(initializer) {
        this._observations = [];
        initializer(this);
        if (!this.options) {
          this.option();
        }
        if (this.options.notify_on_init === true) {
          this.invokeNotification();
        }
        this._eventify();
      }

      Watcher.prototype.option = function(options) {
        if (options == null) {
          options = {};
        }
        return this.options = $.extend({}, ns.Watcher.defaults, options);
      };

      Watcher.prototype.when = function(criteria, handlers) {
        var o;
        o = new ns.Observation(criteria, handlers);
        this._observations.push(o);
        return this;
      };

      Watcher.prototype.notify = function(info) {
        var firedOne, o, _i, _j, _len, _len1, _ref, _ref1;
        firedOne = null;
        _ref = this._observations;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          o = _ref[_i];
          if (o.handleNotification(info)) {
            firedOne = o;
          }
          if (firedOne !== null) {
            break;
          }
        }
        if (firedOne !== null) {
          _ref1 = this._observations;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            o = _ref1[_j];
            if (o !== firedOne) {
              o.resetFiredFlag();
            }
          }
          return this.trigger('observationswitch', info);
        }
      };

      Watcher.prototype.destroy = function() {
        ns.winWatcher.off('resize', this._resizeHandler);
        this._observations.length = 0;
        return this.off();
      };

      Watcher.prototype.invokeNotification = function() {
        return this.notify({
          width: ns.viewport.width()
        });
      };

      Watcher.prototype._eventify = function() {
        var _this = this;
        this._resizeHandler = ns.throttle(function() {
          _this.invokeNotification();
          return _this.trigger('resize');
        }, this.options.throttle_millisec);
        return ns.winWatcher.on('resize', this._resizeHandler);
      };

      return Watcher;

    })(EveEve);
    $.ViewportWatcherNs = ns;
    return $.ViewportWatcher = ns.Watcher;
  })(jQuery);

}).call(this);
