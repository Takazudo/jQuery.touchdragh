/*! jQuery.touchdragh (https://github.com/Takazudo/jQuery.touchdragh)
 * lastupdate: 2013-04-19
 * version: 1.1.2
 * author: 'Takazudo' Takeshi Takatsudo <takazudo@gmail.com>
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
    ns.ua.win8orhigh = (function() {
      var matched, ua, version;
      ua = navigator.userAgent;
      matched = ua.match(/Windows NT ([\d\.]+)/);
      if (!matched) {
        return false;
      }
      version = matched[1] * 1;
      if (version < 6.2) {
        return false;
      }
      return true;
    })();
    ns.getEventNameSet = function(eventName) {
      var res;
      res = {};
      switch (eventName) {
        case 'touchstart':
          res.move = 'touchmove';
          res.end = 'touchend';
          break;
        case 'mousedown':
          res.move = 'mousemove';
          res.end = 'mouseup';
          break;
        case 'MSPointerDown':
          res.move = 'MSPointerMove';
          res.end = 'MSPointerUp';
          break;
        case 'pointerdown':
          res.move = 'pointermove';
          res.end = 'pointerup';
      }
      return res;
    };
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
        $document.bind('gesturestart', function() {
          return ns.whileGesture = true;
        });
        return $document.bind('gestureend', function() {
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
        this.on(ev, function() {
          this.off(ev, arguments.callee);
          return callback.apply(this, arguments);
        });
        return this;
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
        inner: '> *',
        backanim_duration: 250,
        backanim_easing: 'swing',
        beforefirstrefresh: null,
        triggerrefreshimmediately: true,
        tweakinnerpositionstyle: false
      };

      function TouchdraghEl($el, options) {
        this.$el = $el;
        this._handleTouchEnd = __bind(this._handleTouchEnd, this);
        this._handleTouchMove = __bind(this._handleTouchMove, this);
        this._handleTouchStart = __bind(this._handleTouchStart, this);
        this._handleClickToIgnore = __bind(this._handleClickToIgnore, this);
        this.el = this.$el[0];
        this.options = $.extend({}, this.defaults, options);
        this.disabled = false;
        ns.startWatchGestures();
        this._handlePointerEvents();
        this._prepareEls();
        this._eventify();
        if (this.options.triggerrefreshimmediately) {
          this.refresh();
        }
      }

      TouchdraghEl.prototype.refresh = function() {
        this._calcMinMaxLeft();
        this._handleTooNarrow();
        this._handleInnerOver();
        if (!this._firstRefreshDone) {
          if (this.options.beforefirstrefresh) {
            this.options.beforefirstrefresh(this);
          }
          this.trigger('firstrefresh', this);
          this._firstRefreshDone = true;
        }
        this.trigger('refresh', this);
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
        if (this.options.tweakinnerpositionstyle) {
          this.$inner.css({
            position: 'relative'
          });
        }
        return this;
      };

      TouchdraghEl.prototype._calcMinMaxLeft = function() {
        this._maxLeft = 0;
        this._minLeft = -(this.$inner.outerWidth() - this.$el.innerWidth());
        return this;
      };

      TouchdraghEl.prototype._eventify = function() {
        var eventNames;
        eventNames = 'pointerdown MSPointerDown touchstart mousedown';
        this.$el.bind(eventNames, this._handleTouchStart);
        if (ns.support.addEventListener) {
          this.el.addEventListener('click', $.noop, true);
        }
        return this;
      };

      TouchdraghEl.prototype._handleClickToIgnore = function(event) {
        event.stopPropagation();
        event.preventDefault();
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
        if (event.type === 'mousedown') {
          event.preventDefault();
        }
        this._currentEventNameSet = ns.getEventNameSet(event.type);
        this._whileDrag = true;
        this._slidecanceled = false;
        this._shouldSlideInner = false;
        d = this._currentDrag = new ns.OneDrag;
        d.on('yscrolldetected', function() {
          _this._whileDrag = false;
          _this._slidecanceled = true;
          return _this.trigger('slidecancel');
        });
        d.on('xscrolldetected', function() {
          _this._shouldSlideInner = true;
          _this.trigger('dragstart');
          return _this.$el.delegate('a', 'click', _this._handleClickToIgnore);
        });
        d.on('dragmove', function(data) {
          _this.trigger('drag');
          return _this._moveInner(data.x);
        });
        this._innerStartLeft = ns.getLeftPx(this.$inner);
        d.applyTouchStart(event);
        $document.bind(this._currentEventNameSet.move, this._handleTouchMove);
        $document.bind(this._currentEventNameSet.end, this._handleTouchEnd);
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
        var _this = this;
        this._whileDrag = false;
        $document.unbind(this._currentEventNameSet.move, this._handleTouchMove);
        $document.unbind(this._currentEventNameSet.end, this._handleTouchEnd);
        this._currentDrag.destroy();
        this._currentEventNameSet = null;
        if (!this._slidecanceled) {
          this.trigger('dragend');
        }
        setTimeout(function() {
          return _this.$el.undelegate('a', 'click', _this._handleClickToIgnore);
        }, 10);
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
        this.trigger('move', data);
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
            return _this.trigger('moveend');
          }
        };
        to = null;
        left = this.currentSlideLeft();
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
        this.slide(to, true, function() {
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

      TouchdraghEl.prototype.slide = function(val, animate, callback) {
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
          _this.trigger('beforeslide');
          onDone = function() {
            _this.trigger('afterslide');
            if (typeof callback === "function") {
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

      TouchdraghEl.prototype.currentSlideLeft = function() {
        return ns.getLeftPx(this.$inner);
      };

      TouchdraghEl.prototype.updateInnerWidth = function(val) {
        this.$inner.width(val);
        return this;
      };

      return TouchdraghEl;

    })(ns.Event);
    ns.TouchdraghFitty = (function(_super) {

      __extends(TouchdraghFitty, _super);

      TouchdraghFitty.prototype.defaults = {
        item: null,
        beforefirstfresh: null,
        startindex: 0,
        triggerrefreshimmediately: true
      };

      function TouchdraghFitty($el, options) {
        this.$el = $el;
        this.options = $.extend({}, this.defaults, options);
        this.currentIndex = this.options.startindex;
        this._prepareTouchdragh();
        if (this.options.triggerrefreshimmediately) {
          this.refresh();
        }
      }

      TouchdraghFitty.prototype._prepareTouchdragh = function() {
        var options,
          _this = this;
        options = $.extend({}, this.options);
        options.triggerrefreshimmediately = false;
        options.beforefirstrefresh = function(touchdragh) {
          touchdragh.once('firstrefresh', function() {
            var _base;
            if (typeof (_base = _this.options).beforefirstrefresh === "function") {
              _base.beforefirstrefresh(_this);
            }
            _this.trigger('firstrefresh', _this);
            return _this._firstRefreshDone = true;
          });
          touchdragh.on('refresh', function() {
            return _this.trigger('refresh');
          });
          touchdragh.on('slidecancel', function() {
            return _this.trigger('slidecancel');
          });
          touchdragh.on('dragstart', function() {
            return _this.trigger('dragstart');
          });
          touchdragh.on('drag', function() {
            return _this.trigger('drag');
          });
          touchdragh.on('dragend', function() {
            return _this.trigger('dragend');
          });
          return touchdragh.on('moveend', function() {
            var caliculatedIndex, itemW, nextIndex, slidedDistance;
            slidedDistance = -touchdragh.currentSlideLeft();
            itemW = _this.$el.innerWidth();
            nextIndex = null;
            caliculatedIndex = slidedDistance / itemW;
            if (caliculatedIndex < _this.currentIndex) {
              nextIndex = _this.currentIndex - 1;
            } else if (caliculatedIndex > _this.currentIndex) {
              nextIndex = _this.currentIndex + 1;
            }
            if (nextIndex !== null) {
              _this.updateIndex(nextIndex);
              return _this.adjustToFit(itemW, true);
            }
          });
        };
        this._touchdragh = new ns.TouchdraghEl(this.$el, options);
        return this;
      };

      TouchdraghFitty.prototype.updateIndex = function(index) {
        var data, lastIndex;
        if (!((0 <= index && index < this.$items.length))) {
          return false;
        }
        lastIndex = this.currentIndex;
        this.currentIndex = index;
        if (lastIndex !== index) {
          data = {
            index: this.currentIndex
          };
          this.trigger('indexchange', data);
        }
        return true;
      };

      TouchdraghFitty.prototype.refresh = function() {
        var innerW, itemW;
        this.$items = this.$el.find(this.options.item);
        itemW = this._itemWidth = this.$el.innerWidth();
        innerW = itemW * this.$items.length;
        this._touchdragh.updateInnerWidth(innerW);
        this.$items.width(itemW);
        this._touchdragh.refresh();
        this.adjustToFit(itemW);
        return this;
      };

      TouchdraghFitty.prototype.adjustToFit = function(itemWidth, animate, callback) {
        var _this = this;
        if (animate == null) {
          animate = false;
        }
        if (itemWidth == null) {
          itemWidth = this.$items.width();
        }
        return $.Deferred(function(defer) {
          var i, left_after, left_pre;
          i = _this.currentIndex;
          left_after = -itemWidth * i;
          left_pre = _this._touchdragh.currentSlideLeft();
          if (left_after === left_pre) {
            defer.resolve();
            return _this;
          }
          if (!_this._sliding) {
            _this.trigger('slidestart');
          }
          _this._sliding = true;
          return _this._touchdragh.slide(left_after, animate, function() {
            var data;
            _this._sliding = false;
            data = {
              index: _this.currentIndex
            };
            _this.trigger('slideend', data);
            if (typeof callback === "function") {
              callback();
            }
            return defer.resolve();
          });
        }).promise();
      };

      TouchdraghFitty.prototype.to = function(index, animate) {
        var updated,
          _this = this;
        if (animate == null) {
          animate = false;
        }
        updated = this.updateIndex(index);
        return $.Deferred(function(defer) {
          if (updated) {
            return _this.adjustToFit(null, animate, function() {
              return defer.resolve();
            });
          } else {
            _this.trigger('invalidindexrequested');
            return defer.resolve();
          }
        }).promise();
      };

      TouchdraghFitty.prototype.next = function(animate) {
        if (animate == null) {
          animate = false;
        }
        return this.to(this.currentIndex + 1, animate);
      };

      TouchdraghFitty.prototype.prev = function(animate) {
        if (animate == null) {
          animate = false;
        }
        return this.to(this.currentIndex - 1, animate);
      };

      return TouchdraghFitty;

    })(ns.Event);
    $.fn.touchdragh = function(options) {
      return this.each(function(i, el) {
        var $el, instance;
        $el = $(el);
        instance = new ns.TouchdraghEl($el, options);
        $el.data('touchdragh', instance);
      });
    };
    $.fn.touchdraghfitty = function(options) {
      return this.each(function(i, el) {
        var $el, instance;
        $el = $(el);
        instance = new ns.TouchdraghFitty($el, options);
        $el.data('touchdraghfitty', instance);
      });
    };
    $.Touchdragh = ns.TouchdraghEl;
    return $.TouchdraghFitty = ns.TouchdraghFitty;
  })(jQuery, window, document);

}).call(this);
