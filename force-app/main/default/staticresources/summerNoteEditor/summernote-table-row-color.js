(function (factory) {
    /* global define */
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof module === 'object' && module.exports) {
        // Node/CommonJS
        module.exports = factory(require('jquery'));
    } else {
        // Browser globals
        factory(window.jQuery);
    }
}(function ($) {

    // Extends plugins for custom row color plugin.
    $.extend($.summernote.plugins, {

        'rowColor': function (context) {
            var self = this,
                ui = $.summernote.ui,
                options = context.options,
                lang = options.langInfo;
                $editor = context.layoutInfo.editor,
                $editable = context.layoutInfo.editable;

            context.memo('button.rowColor', function () {
                var rng = context.invoke('createRange', $editable);
                var defaultColor = '#ffffff';
                if (rng.isOnCell()) {
                    var $tr = $(rng.sc).closest('tr');
                    defaultColor = $tr.css('background-color')
                }
                return self.colorPaletteCustome('row-color', 'Change Row Color', defaultColor, 'Select Row Colors', 'rowColorSelection');
            });

            this.setRowColor = function (color) {
                // Check if selection is inside a table row
                var rng = context.invoke('createRange', $editable);
                if (!rng.isOnCell()) {
                    return;
                }
                // Get the table row
                var $tr = $(rng.sc).closest('tr');
                // Set background color of the table row
                $tr.css('background-color', color);
            };

            this.initialize = function(){
                console.log('row color');
            }

            this.colorPaletteCustome = function(className, tooltip, defaultColor, PaletTitle, selectionEvent){
                try {
                    return ui.buttonGroup({
                      className: 'note-color ' + className,
                      tooltip : tooltip,
                      children: [
                        ui.button({
                          className: 'dropdown-toggle',
                          contents: '<b>R</b>',
                          tooltip: tooltip,
                          data: {
                            toggle: 'dropdown',
                          },
                        }),
                        ui.dropdown({
                          items:[
                            '<div class="note-palette">',
                              '<div class="note-palette-title">' + PaletTitle + '</div>',
                              '<div>',
                                '<button type="button" class="note-color-reset btn btn-light btn-default" data-event="'+ selectionEvent +'" data-value="transparent">',
                                  lang.color.transparent,
                                '</button>',
                              '</div>',
                              '<div class="note-holder" data-event="'+ selectionEvent +'"><!-- Select colors --></div>',
                              '<div>',
                                '<button type="button" class="note-color-select btn btn-light btn-default" data-event="openPalette" data-value="colorPicker-'+options.id+'">',
                                  lang.color.cpSelect,
                                '</button>',
                                '<input type="color" id="colorPicker-'+options.id+'" class="note-btn note-color-select-btn" value="' + defaultColor + '" data-event="recentColors-'+options.id+'">',
                              '</div>',
                              '<div class="note-holder-custom" id="recentColors-'+options.id+'" data-event="'+ selectionEvent +'"></div>',
                            '</div>',
                          ].join(''),
                          callback: ($dropdown) => {
                            $dropdown.find('.note-holder').each((idx, item) => {
                              const $holder = $(item);
                              $holder.append(ui.palette({
                                colors: options.colors,
                                colorsName: options.colorsName,
                                eventName: $holder.data('event'),
                                container: options.container,
                                tooltip: options.tooltip,
                              }).render());
                            });
                            /* TODO: do we have to record recent custom colors within cookies? */
                            var customColors = [
                              ['#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF', '#FFFFFF'],
                            ];
                            $dropdown.find('.note-holder-custom').each((idx, item) => {
                              const $holder = $(item);
                              $holder.append(ui.palette({
                                colors: customColors,
                                colorsName: customColors,
                                eventName: $holder.data('event'),
                                container: options.container,
                                tooltip: options.tooltip,
                              }).render());
                            });
                            $dropdown.find('input[type=color]').each((idx, item) => {
                                $(item).on("change", function() {
                                const $parent = $('.' + className).find('.note-dropdown-menu');
                                const $palette = $($parent.find('#' + $(this).data('event')).find('.note-color-row')[0]);
                                const $chip = $palette.find('.note-color-btn').last().detach();
                                const color = this.value.toUpperCase();
                                $chip.css('background-color', color)
                                    .attr('aria-label', color)
                                    .attr('data-value', color)
                                    .attr('data-original-title', color);
                                $chip.trigger('click');
                                $palette.prepend($chip);

                                // Set Color Based On Color-Picker Value;
                                self.setRowColor(color);
                              });
                            });
                          },
                          click: (event) => {
                            event.stopPropagation();
                  
                            const $parent = $('.' + className).find('.note-dropdown-menu');
                            const $button = $(event.target);
                            const eventName = $button.data('event');
                            const value = $button.attr('data-value');
                  
                            if (eventName === 'openPalette') {
                              const $picker = $parent.find('#' + value);
                              const $palette = $($parent.find('#' + $picker.data('event')).find('.note-color-row')[0]);
                  
                              // Shift palette chips
                              const $chip = $palette.find('.note-color-btn').last().detach();
                  
                              // Set chip attributes
                              const color = $picker.val();
                              $chip.css('background-color', color)
                                .attr('aria-label', color)
                                .attr('data-value', color)
                                .attr('data-original-title', color);
                              $palette.prepend($chip);
                              $picker.trigger('click');
                            
                              // Set Color Based On Color-Picker Value;
                              self.setRowColor(color);
                            } else if(eventName === selectionEvent ){
                                // Set color based on color selection....                  
                                self.setRowColor(value);
                            }
                          },
                        }),
                      ],
                    }).render();
                } catch (error) {
                    console.log('error in colorPaletteCustome', error.stack);
                }
            }
        }
    });
}));
