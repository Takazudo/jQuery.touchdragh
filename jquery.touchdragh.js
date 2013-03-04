/*! jQuery.touchdragh (https://github.com/Takazudo/jQuery.touchdragh)
 * lastupdate: 2013-03-05
 * version: 0.0.0
 * author: Takeshi Takatsudo 'Takazudo' <takazudo@gmail.com>
 * License: MIT */
(function() {
  var __slice = [].slice,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  (function($, window, document) {
    var $document, ns;
    $document = $(document);
    ns = $.TouchdraghNs = {};
    ns.normalizeXY = function(event) {
      var orig, res, touch;
      res = {};
      orig = event.originalEvent;
      if (orig.changedTouches != null) {
        touch = orig.changedTouches[0];
        res.x = touch.pageX;
        res.y = touch.pageY;
      } else {
        res.x = event.pageX || orig.pageX;
        res.y = event.pageY || orig.pageY;
      }
      return res;
    };
    ns.support = {};
    ns.ua = {};
    ns.support.addEventListener = 'addEventListener' in document;
    ns.support.touch = 'ontouchend' in document;
    ns.support.mspointer = window.navigator.msPointerEnabled || false;
    ns.ua.win8 = /Windows NT 6\.2/i.test(navigator.userAgent);
    ns.touchStartEventName = (function() {
      if (ns.support.mspointer) {
        return 'MSPointerDown';
      }
      if (ns.ua.win8) {
        return 'touchstart mousedown';
      }
      if (ns.support.touch) {
        return 'touchstart';
      }
      return 'mousedown';
    })();
    ns.touchMoveEventName = (function() {
      if (ns.support.mspointer) {
        return 'MSPointerMove';
      }
      if (ns.ua.win8) {
        return 'touchmove mousemove';
      }
      if (ns.support.touch) {
        return 'touchmove';
      }
      return 'mousemove';
    })();
    ns.touchEndEventName = (function() {
      if (ns.support.mspointer) {
        return 'MSPointerUp';
      }
      if (ns.ua.win8) {
        return 'touchend mouseup';
      }
      if (ns.support.touch) {
        return 'touchend';
      }
      return 'mouseup';
    })();
    ns.getLeftPx = function($el) {
      var l;
      l = $el.css('left');
      if (l === 'auto') {
        l = 0;
      } else {
        l = (l.replace(/px/, '')) * 1;
      }
      return l;
    };
    ns.startWatchGestures = (function() {
      var init, initDone;
      initDone = false;
      init = function() {
        initDone = true;
        $document.on('gesturestart', function() {
          return ns.whileGesture = true;
        });
        return $document.on('gestureend', function() {
          return ns.whileGesture = false;
        });
      };
      return function() {
        if (this.initDone) {
          return;
        }
        return init();
      };
    })();
    ns.Event = (function() {

      function Event() {}

      Event.prototype.on = function(ev, callback) {
        var evs, name, _base, _i, _len;
        if (this._callbacks == null) {
          this._callbacks = {};
        }
        evs = ev.split(' ');
        for (_i = 0, _len = evs.length; _i < _len; _i++) {
          name = evs[_i];
          (_base = this._callbacks)[name] || (_base[name] = []);
          this._callbacks[name].push(callback);
        }
        return this;
      };

      Event.prototype.once = function(ev, callback) {
        return this.on(ev, function() {
          this.off(ev, arguments.callee);
          return callback.apply(this, arguments);
        });
      };

      Event.prototype.trigger = function() {
        var args, callback, ev, list, _i, _len, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        ev = args.shift();
        list = (_ref = this._callbacks) != null ? _ref[ev] : void 0;
        if (!list) {
          return;
        }
        for (_i = 0, _len = list.length; _i < _len; _i++) {
          callback = list[_i];
          if (callback.apply(this, args) === false) {
            break;
          }
        }
        return this;
      };

      Event.prototype.off = function(ev, callback) {
        var cb, i, list, _i, _len, _ref;
        if (!ev) {
          this._callbacks = {};
          return this;
        }
        list = (_ref = this._callbacks) != null ? _ref[ev] : void 0;
        if (!list) {
          return this;
        }
        if (!callback) {
          delete this._callbacks[ev];
          return this;
        }
        for (i = _i = 0, _len = list.length; _i < _len; i = ++_i) {
          cb = list[i];
          if (!(cb === callback)) {
            continue;
          }
          list = list.slice();
          list.splice(i, 1);
          this._callbacks[ev] = list;
          break;
        }
        return this;
      };

      return Event;

    })();
    ns.OneDrag = (function(_super) {

      __extends(OneDrag, _super);

      function OneDrag() {
        this._scrollDirectionDecided = false;
      }

      OneDrag.prototype.applyTouchStart = function(touchStartEvent) {
        var coords;
        coords = ns.normalizeXY(touchStartEvent);
        this.startPageX = coords.x;
        this.startPageY = coords.y;
        return this;
      };

      OneDrag.prototype.applyTouchMove = function(touchMoveEvent) {
        var coords, distX, distY, triggerEvent,
          _this = this;
        coords = ns.normalizeXY(touchMoveEvent);
        triggerEvent = function() {
          var diffX;
          diffX = coords.x - _this.startPageX;
          return _this.trigger('dragmove', {
            x: diffX
          });
        };
        if (this._scrollDirectionDecided) {
          triggerEvent();
        } else {
          distX = Math.abs(coords.x - this.startPageX);
          distY = Math.abs(coords.y - this.startPageY);
          if ((distX > 5) || (distY > 5)) {
            this._scrollDirectionDecided = true;
            if (distX > 5) {
              this.trigger('xscrolldetected');
            } else if (distY > 5) {
              this.trigger('yscrolldetected');
            }
          }
        }
        return this;
      };

      OneDrag.prototype.destroy = function() {
        this.off();
        return this;
      };

      return OneDrag;

    })(ns.Event);
    ns.TouchdraghEl = (function(_super) {

      __extends(TouchdraghEl, _super);

      TouchdraghEl.prototype.defaults = {
        backanim_duration: 250,
        backanim_easing: 'swing',
        beforefirstrefresh: null
      };

      function TouchdraghEl($el, options) {
        this.$el = $el;
        this._handleTouchEnd = __bind(this._handleTouchEnd, this);
        this._handleTouchMove = __bind(this._handleTouchMove, this);
        this._handleTouchStart = __bind(this._handleTouchStart, this);
        this._firstRefreshDone = false;
        this.el = this.$el[0];
        this.options = $.extend({}, this.defaults, options);
        this.disabled = false;
        ns.startWatchGestures();
        this._handlePointerEvents();
        this._prepareEls();
        this._eventify();
        this.refresh();
      }

      TouchdraghEl.prototype.refresh = function() {
        this._calcMinMaxLeft();
        this._handleTooNarrow();
        this._handleInnerOver();
        if (!this._firstRefreshDone) {
          if (this.options.beforefirstrefresh) {
            this.options.beforefirstrefresh(this);
          }
          this.trigger('touchdragh.firstrefresh');
          this._firstRefreshDone = true;
        }
        this.trigger('touchdragh.refresh');
        return this;
      };

      TouchdraghEl.prototype._handlePointerEvents = function() {
        if (!ns.support.mspointer) {
          return this;
        }
        this.el.style.msTouchAction = 'none';
        return this;
      };

      TouchdraghEl.prototype._prepareEls = function() {
        this.$inner = this.$el.find(this.options.inner);
        return this;
      };

      TouchdraghEl.prototype._calcMinMaxLeft = function() {
        this._maxLeft = 0;
        this._minLeft = -(this.$inner.outerWidth() - this.$el.innerWidth());
        return this;
      };

      TouchdraghEl.prototype._eventify = function() {
        this.$el.on(ns.touchStartEventName, this._handleTouchStart);
        if (ns.support.addEventListener) {
          this.el.addEventListener('click', $.noop, true);
        }
        return this;
      };

      TouchdraghEl.prototype._handleTouchStart = function(event) {
        var d,
          _this = this;
        if (this.disabled) {
          return this;
        }
        if (this._whileDrag) {
          return this;
        }
        if (ns.whileGesture) {
          return this;
        }
        if (event.type === 'mouedown') {
          event.preventDefault();
        }
        this._whileDrag = true;
        this._shouldSlideInner = false;
        d = this._currentDrag = new ns.OneDrag;
        d.on('yscrolldetected', function() {
          return _this._whileDrag = false;
        });
        d.on('xscrolldetected', function() {
          _this._shouldSlideInner = true;
          return _this.trigger('touchdragh.start');
        });
        d.on('dragmove', function(data) {
          _this.trigger('touchdragh.drag');
          return _this._moveInner(data.x);
        });
        this._innerStartLeft = ns.getLeftPx(this.$inner);
        d.applyTouchStart(event);
        $document.on(ns.touchMoveEventName, this._handleTouchMove);
        $document.on(ns.touchEndEventName, this._handleTouchEnd);
        return this;
      };

      TouchdraghEl.prototype._handleTouchMove = function(event) {
        if (!this._whileDrag) {
          return this;
        }
        if (ns.whileGesture) {
          return this;
        }
        this._currentDrag.applyTouchMove(event);
        if (this._shouldSlideInner) {
          event.preventDefault();
          event.stopPropagation();
        }
        return this;
      };

      TouchdraghEl.prototype._handleTouchEnd = function(event) {
        this._whileDrag = false;
        $document.off(ns.touchMoveEventName, this._handleTouchMove);
        $document.off(ns.touchEndEventName, this._handleTouchEnd);
        this._currentDrag.destroy();
        this._handleInnerOver(true);
        return this;
      };

      TouchdraghEl.prototype._moveInner = function(x) {
        var data, left;
        left = this._innerStartLeft + x;
        if (left > this._maxLeft) {
          left = this._maxLeft + ((left - this._maxLeft) / 3);
        } else if (left < this._minLeft) {
          left = this._minLeft + ((left - this._minLeft) / 3);
        }
        this.$inner.css('left', left);
        data = {
          left: left
        };
        this.trigger('touchdragh.move', data);
        return this;
      };

      TouchdraghEl.prototype._handleInnerOver = function(invokeEndEvent) {
        var belowMin, left, overMax, to, triggerEvent,
          _this = this;
        if (invokeEndEvent == null) {
          invokeEndEvent = false;
        }
        if (this.isInnerTooNarrow()) {
          return this;
        }
        triggerEvent = function() {
          if (invokeEndEvent) {
            return _this.trigger('touchdragh.end');
          }
        };
        to = null;
        left = ns.getLeftPx(this.$inner);
        overMax = left > this._maxLeft;
        belowMin = left < this._minLeft;
        if (!(overMax || belowMin)) {
          triggerEvent();
          return this;
        }
        if (overMax) {
          to = this._maxLeft;
        }
        if (belowMin) {
          to = this._minLeft;
        }
        this.slideInner(to, true, function() {
          return triggerEvent();
        });
        return this;
      };

      TouchdraghEl.prototype._handleTooNarrow = function() {
        if (this.isInnerTooNarrow()) {
          this.disable();
          this.$inner.css('left', 0);
        } else {
          this.enable();
        }
        return this;
      };

      TouchdraghEl.prototype.isInnerTooNarrow = function() {
        var elW, innerW;
        elW = this.$el.width();
        innerW = this.$inner.width();
        return innerW <= elW;
      };

      TouchdraghEl.prototype.disable = function() {
        this.disabled = true;
        return this;
      };

      TouchdraghEl.prototype.enable = function() {
        this.disabled = false;
        return this;
      };

      TouchdraghEl.prototype.slideInner = function(val, animate, callback) {
        var d, e, to,
          _this = this;
        if (animate == null) {
          animate = false;
        }
        if (val > this._maxLeft) {
          val = this._maxLeft;
        }
        if (val < this._minLeft) {
          val = this._minLeft;
        }
        d = this.options.backanim_duration;
        e = this.options.backanim_easing;
        to = {
          left: val
        };
        return $.Deferred(function(defer) {
          var onDone;
          _this.trigger('touchdragh.beforeinnerslide');
          onDone = function() {
            _this.trigger('touchdragh.afterinnerslide');
            if (callback != null) {
              callback();
            }
            return defer.resolve();
          };
          if (animate) {
            return _this.$inner.stop().animate(to, d, e, function() {
              return onDone();
            });
          } else {
            _this.$inner.stop().css(to);
            return onDone();
          }
        }).promise();
      };

      return TouchdraghEl;

    })(ns.Event);
    $.fn.touchdragh = function(options) {
      if (options == null) {
        options = {};
      }
      return this.each(function(i, el) {
        var $el, instance;
        $el = $(el);
        instance = new ns.TouchdraghEl($el, options);
        $el.data('touchdragh', instance);
        return this;
      });
    };
    return $.Touchdragh = ns.TouchdraghEl;
  })(jQuery, window, document);

}).call(this);