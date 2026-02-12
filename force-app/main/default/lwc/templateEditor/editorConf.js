import { customeIcons } from 'c/globalProperties';
var _self;

/**
 * Method to set CSS of HTML Elements Once Editor Load SuccessFully...
 * @param {*} note 
 */
function setCSSAfterLoadEditor(note) {
  try {
    note.noteEditorFrame = note.summerNote.nextSibling;
    note.noteEditorFrame.setAttribute('data-zone', note.selector);
    note.noteEditorFrame.classList.add(note.selector);

    const page = note.noteEditorFrame.querySelector('.note-editable');
    page.setAttribute('data-editor', note.selector);
    page.classList.add(note.selector);

    // There is some issue or bug in summerNote js that not make editor enable...
    // So we make it using our logic....
    page.setAttribute('contenteditable', 'true');

  } catch (error) {
    console.warn('error in setCSSAfterLoadEditor : ', error.stack);
  }
}

// *** ======== ===== ======  Set Font Size Using Custom Button -- START ======== ===== ====== ========
/**
 * Method to  // set font-resize input value as per selected text font-size...
 * this method will triggers when user change mouse position OR editor value changed...
 * @param {*} note 
 */
function setFontResizerValue(note) {
  try {
    // get Editor CurrentStyle;
    var styleInfo = $(note.summerNote).summernote('editor.currentStyle');

    var fontResizer = note.summerNote.nextSibling.querySelector(`[data-name="font-input"]`);
    if (fontResizer) {
      fontResizer.value = styleInfo['font-size'];
    }
  } catch (error) {
    console.warn('error in editorConfig.setFontResizerValue : ',);
  }
}
/**
 * Method to Set Font-Size in Editor...
 * @param {*} event 
 * @param {*} note 
 */
function setFontSize(event, note) {

  // get Editor CurrentStyle;
  var styleInfo = $(note.summerNote).summernote('editor.currentStyle');

  // When User Click MINUS Button...
  if (event.currentTarget.dataset.name == 'font-minus') {
    note.summerNote.nextSibling.querySelector(`[data-name="font-input"]`).value = parseInt(styleInfo['font-size'] - 1);
    $(note.summerNote).summernote('fontSize', parseInt(styleInfo['font-size'] - 1));
  }
  // When User Click PLUS Button...
  else if (event.currentTarget.dataset.name == 'font-plus') {
    note.summerNote.nextSibling.querySelector(`[data-name="font-input"]`).value = parseInt(styleInfo['font-size']) + 1;
    $(note.summerNote).summernote('fontSize', parseInt(styleInfo['font-size']) + 1);
  }
  // When USer Interact with Inut Field...
  else if (event.currentTarget.dataset.name == 'font-input') {
    // Save selection range before click on input
    $(note.summerNote).summernote('saveRange');

    // When User Focus on Input... Select all value...
    if (event.type == 'focus') {
      this.select();
    }
    //When User Chnage Value Of Font-Size Input...         
    else if (event.type == 'change') {
      var inputValue = event.target.value;
      if (inputValue > 100) {
        inputValue = 100;
      }
      else if (inputValue <= 0) {
        inputValue = 2;
      }

      // restore selection range before apply font-size;
      $(note.summerNote).summernote('restoreRange');
      // Apply Font-size as per User Defiend Value...
      $(note.summerNote).summernote('fontSize', parseInt(inputValue));
      event.target.value = parseInt(inputValue);
    }
    // Prevent User to enter non-numeric value...
    else if (event.type == 'keypress') {
      const keyCode = event.which || event.keyCode;

      if (keyCode < 48 || keyCode > 57) {
        event.preventDefault();
      }
    }

  }
}
/**
 * Method to create and return custom fontResize BUTTON....
 * @param {*} note 
 * @returns 
 */
function createFontResizer(note) {
  if (typeof window !== 'undefined') {
    var fontReiszerContanier = document?.createElement('div');
    fontReiszerContanier.classList.add('fontResizer');

    var minusBtn = document?.createElement('span');
    minusBtn.classList.add('minusBtn');
    minusBtn.setAttribute("data-name", "font-minus");
    // minusBtn.innerText = 'A-';
    minusBtn.innerHTML = customeIcons.minusSize
    minusBtn.addEventListener('click', function (e) { setFontSize(e, note) });
    fontReiszerContanier.appendChild(minusBtn);

    var sizeInput = document?.createElement('input');
    sizeInput.setAttribute("type", "number");
    sizeInput.setAttribute("data-name", "font-input");
    sizeInput.value = 13;
    sizeInput.classList.add('sizeInput');
    sizeInput.addEventListener('change', function (e) { setFontSize(e, note) });
    sizeInput.addEventListener('focus', function (e) { setFontSize(e, note) });
    sizeInput.addEventListener('keypress', function (e) { setFontSize(e, note) });
    fontReiszerContanier.appendChild(sizeInput);

    var plusBtn = document?.createElement('span');
    plusBtn.classList.add('plusBtn');
    plusBtn.addEventListener('click', function (e) { setFontSize(e, note) });
    // plusBtn.innerText = 'A+';
    plusBtn.innerHTML = customeIcons.plusSize
    plusBtn.setAttribute("data-name", "font-plus");
    fontReiszerContanier.appendChild(plusBtn);

    var ui = $.summernote.ui;
    // create button
    var button = ui.button({
      contents: fontReiszerContanier,
      tooltip: 'Set font-size',
      click: function () {
        // invoke insertText method with 'hello' on editor module.
      }
    });
    return button.render();   // return button as jquery object
  }
  return null;
}

// ======== ===== ====== Set Font Size Using Custom Button  - END ======== ===== ====== ========

// *** ======== ===== ====== Set Table Row Color Custom Button -- START ======== ===== ====== ========
/**
 * Method to create a button with custom color palette dropdown... 
 * this method is Replicated from summerNote JS File, so be careful to made any changes....
 * @param {*} className 
 * @param {*} infoOpt 
 * @param {*} defaultColor 
 * @param {*} PaletTitle 
 * @param {*} callBackFnc 
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function colorPalette_CusBtn(className, infoOpt, defaultColor, PaletTitle, callBackFnc, note, context) {

  var ui = $.summernote.ui;
  var options = context.options;
  var lang = context.options.langInfo;
  return ui.buttonGroup({
    className: 'note-color ' + className,
    tooltip: lang.custom[infoOpt],
    children: [
      ui.button({
        className: 'dropdown-toggle setMaxWidth',
        contents: options.icons[infoOpt],
        data: {
          toggle: 'dropdown',
        },
      }),
      ui.dropdown({
        items: [
          '<div class="note-palette">',
          '<div class="note-palette-title">' + PaletTitle + '</div>',
          '<div>',
          '<button type="button" class="note-color-reset btn btn-light btn-default" data-event="' + 'selectionEvent' + '" data-value="transparent">',
          lang.color.transparent,
          '</button>',
          '</div>',
          '<div class="note-holder" data-event="' + 'selectionEvent' + '"><!-- Select colors --></div>',
          '<div>',
          '<button type="button" class="note-color-select btn btn-light btn-default" data-event="openPalette" data-value="colorPicker-' + options.id + '">',
          lang.color.cpSelect,
          '</button>',
          '<input type="color" id="colorPicker-' + options.id + '" class="note-btn note-color-select-btn" value="' + defaultColor + '" data-event="recentColors-' + options.id + '">',
          '</div>',
          '<div class="note-holder-custom" id="recentColors-' + options.id + '" data-event="' + 'selectionEvent' + '"></div>',
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
            $(item).on("change", function () {
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
              callBackFnc(color, note, context);
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
            callBackFnc(color, note, context);
          }
          else {
            //  if(eventName === selectionEvent ){
            // Set color based on color selection....                  
            callBackFnc(value, note, context);
            //  }
          }
        },
      }),
    ],
  }).render();
}

/**
 * Method to set Table row color
 * @param {*} color 
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function setTableRowColor(color, note, context) {
  try {
    // Check if selection is inside a table row
    var editable = context.layoutInfo.editable;
    var rng = context.invoke('createRange', editable);

    if (!rng.isOnCell()) {
      return;
    }
    // Get the table row
    var $tr = $(rng.sc).closest('tr');
    // Set background color of the table row
    $tr.css('background-color', color);
  } catch (error) {
    console.warn('error in setTableRowColor : ', error.stack);

  }
};

/**
 * Method to create custom Button to set Table Row Color
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function createRowColorBtn(note, context) {
  var defaultColor = '#ffffff';
  return colorPalette_CusBtn('row-color', 'rowcolor', defaultColor, 'Select Row Colors', setTableRowColor, note, context);
}

/**
 * Method to set Table Border color using table popover button
 * @param {*} color 
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function setTableBorderColor(color, note, context) {
  try {
    // Check if selection is inside a table row
    var editable = context.layoutInfo.editable;
    var rng = context.invoke('createRange', editable);
    // const rng = $(note.summerNote).summernote('editor.getLastRange');

    if (!rng.isOnCell()) {
      return;
    }

    // Set background color of the table td and th
    $(rng.sc).closest('table').find('td', 'th').css('border-color', color);
  } catch (error) {
    console.warn('error in setTableRowColor : ', error.stack);

  }
}

/**
 * Method to create custom Button to set Table Border Color
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function createBorderColorBtn(note, context) {
  var defaultColor = '#000000';
  return colorPalette_CusBtn('border-color', 'bordercolor', defaultColor, 'Select Border Colors', setTableBorderColor, note, context);
}

/**
 * Method to set Table Cell color
 * @param {*} color 
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function setTableCellColor(color, note, context) {
  try {
    // Check if selection is inside a table row
    var editable = context.layoutInfo.editable;
    var rng = context.invoke('createRange', editable);
    // const rng = $(note.summerNote).summernote('editor.getLastRange');

    if (!rng.isOnCell()) {
      return;
    }

    // Get the table row
    var $td = $(rng.sc).closest('td');
    var $th = $(rng.sc).closest('td');
    if ($td.length > 0) {
      $td.css('background-color', color);
    }
    else if ($th.length > 0) {
      $th.css('background-color', color);
    }
  } catch (error) {
    console.warn('error in setTableRowColor : ', error.stack);

  }
}

/**
 * Method to create custom Button to set Table Single Cell Color
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function createCellColorBtn(note, context) {
  var defaultColor = '#ffffff';
  return colorPalette_CusBtn('cell-color', 'cellcolor', defaultColor, 'Select Cell Colors', setTableCellColor, note, context);
}

// ======== ====== ====== Set Table Row Color Custom Button - END ======== ===== ====== ========

/**
 * Method to set Alignment of text into table using popper button
 * @param {*} position 
 * @param {*} context 
 * @returns 
 */
function setCellVerticalAlighn(position, context) {
  try {
    // Check if selection is inside a table row
    var editable = context.layoutInfo.editable;
    var rng = context.invoke('createRange', editable);
    // const rng = $(note.summerNote).summernote('editor.getLastRange');

    if (!rng.isOnCell()) {
      return;
    }

    // Get the table row
    var $td = $(rng.sc).closest('td');
    var $th = $(rng.sc).closest('td');
    if ($td.length > 0) {
      $td.css('vertical-align', position);
    }
    else if ($th.length > 0) {
      $th.css('vertical-align', position);
    }
  } catch (error) {
    console.warn('error in setCellVerticalAlighn : ', error.stack);

  }
}
/**
 * Method to generate cell vertical custom button 
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function createCellVerticalAlignBtn(note, context) {

  var ui = $.summernote.ui;
  var options = context.options;
  var lang = context.options.langInfo;
  lang.topAlign = 'Top Align';
  lang.bottomAlign = 'Bottom Align';
  lang.centerAlign = 'Center Align';
  lang.baselineAlign = 'Baseline Align';

  return ui.buttonGroup([
    ui.button({
      className: 'dropdown-toggle',
      contents: ui.dropdownButtonContents(ui.icon(options.icons.alignLeft), options),
      tooltip: lang.verticalAlign,
      container: options.container,
      data: {
        toggle: 'dropdown',
      },
    }),
    ui.dropdown({
      className: 'custom-align-dropdown',
      children: [
        ui.button({
          className: 'custom-vertical-align-btn-top',
          // contents : ui.icon(options.icons.alignJustify),
          contents: customeIcons.aligntop,
          tooltip: lang.topAlign,
          click: function () { setCellVerticalAlighn('top', context) }
        }),
        ui.button({
          className: 'custom-vertical-align-btn-middle',
          // contents : ui.icon(options.icons.alignJustify),
          contents: customeIcons.alignmiddle,
          tooltip: lang.centerAlign,
          click: function () { setCellVerticalAlighn('middle', context) }
        }),
        ui.button({
          className: 'custom-vertical-align-btn-bottom',
          // contents : ui.icon(options.icons.alignJustify),
          contents: customeIcons.alignbottom,
          tooltip: lang.bottomAlign,
          click: function () { setCellVerticalAlighn('bottom', context) }
        }),
        // ui.button({
        //     className: 'custom-vertical-align-btn-baseline',
        //     contents : customeIcons.aligntop,
        //     tooltip  : lang.baselineAlign,
        //     click: function () {setCellVerticalAlighn('baseline', context)}
        // })
      ]
    }),

  ]).render();
}


function preventPageBreakInHeaderFooter(note, event) {
  if ((note.selector == 'headerEditor' || note.selector == 'footerEditor') && (event.ctrlKey || event.metaKey) && event.key == 'Enter') {
    event.preventDefault();
  }
}


//  ==== ===== ======= ====== Page Setup Methods -- START ==== ==== ==== ==== 

/**
 * Method to create page-setup custom button
 * @param {*} note 
 * @param {*} context 
 * @returns 
 */
function createPageSetupBtn(note, context) {
  var ui = $.summernote.ui;
  var options = context.options;
  var lang = options.langInfo;
  lang.pageSetup = 'Page Configurations';

  return ui.buttonGroup([
    ui.button({
      className: 'pageSetup-toggle',
      contents: customeIcons.pageSetup,
      tooltip: lang.pageSetup,
      click: function () {
        // _self.activeTabName = 'basicTab';
        _self.togglePageConfigPopover();
        // _self.setActiveTab();
        // _self.SetCSSbasedOnScreenChangeIn();
      }
    })
  ]).render();
}
//  ==== ===== ======= ====== Page Setup Methods -- END ==== ==== ==== ==== 

//  ==== ===== ======= ====== Related List (Child Table) calculation method -- END ==== ==== ==== ==== 

// === ==== ====  Configuration method for summernote Editor === ==== ==== 

/**
 * This is main method to initialize editor into DOM,
 * Use can use this method multiple time to initialize multiple editor,
 * @param {*} self 
 * @param {*} docGeniusLogoSvg 
 * @param {*} editorSelector 
 * @returns 
 */
export function initializeSummerNote(self, docGeniusLogoSvg, editorSelector) {
  try {
    var note = {
      summerNote: null,
      selector: null,
      noteEditorFrame: null,
    }

    _self = self;
    note.selector = editorSelector;
    note.summerNote = _self.template.querySelector(`[data-name="${note.selector}"]`);

    var placeHolder = '';
    switch (note.selector) {
      case 'templateContent':
        placeHolder = 'Add/Insert Template Content';
        break;

      case 'headerEditor':
        placeHolder = 'Add/Insert Template Header';
        break;

      case 'footerEditor':
        placeHolder = 'Add/Insert Template Footer';
        break;

    }

    // Create new fontResize Custom BUTTON....
    var fontResizerBtn = function (context) {
      return createFontResizer(note, context);
    }

    var createBuilderTitle = function () {
      var titleImg = `<div class="docGeniusLogo"><p>Powered By</p><img src=${docGeniusLogoSvg}></img></div>`
      return titleImg;
    }

    var rowcolorbtn = function (context) {
      return createRowColorBtn(note, context)
    }

    var borderColorBtn = function (context) {
      return createBorderColorBtn(note, context)
    }

    var cellColorBtn = function (context) {
      return createCellColorBtn(note, context)
    }

    var cellVerticalAlignBtn = function (context) {
      return createCellVerticalAlignBtn(note, context);
    };

    var pageSetupBtn = function (context) {
      return createPageSetupBtn(note, context)
    }

    const toolbarOptions = [

      // Customized Toolbar 
      // ['custom_backup', ['undo','redo']],
      // 'fontsize'
      ['custom_pageSetup', ['pageSetup']],
      ['custom_fontFormattings', ['fontname', 'fontResizer', 'forecolor', 'backcolor', 'bold', 'italic', 'underline', 'strikethrough', 'superscript', 'subscript']],
      ['custom_paragraphFormatting', ['ul', 'ol', 'paragraph', 'height']],
      ['custom_style', ['style']],
      ['custom_insert', ['table', 'link', 'picture', 'hr']],
      // ['custom_clearFormatting', ['truncate','clear']],
      ['custom_clearFormatting', ['clear']],
      ['custom_view', ['codeview', 'help']],
      //['custom_title', ['titleBtn']],
    ]

    // remove page backer for header and footer editor.
    if (note.selector == 'headerEditor' || note.selector == 'footerEditor') {
      (toolbarOptions[4][1])?.splice(3, 1);
    }

    // Initialize SummerNote Editor...
    $(note.summerNote).summernote({

      editing: true,
      // placeholder: 'Welcome To The EstateXpert Template Builder. A Place Where You Can Create Your Amazing Documentation...',
      placeholder: placeHolder,
      styleTags: ['p', 'blockquote', 'pre', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'],
      fontSizes: ['8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '26', '28', '30', '32', '34', '36', '38', '40', '42', '44', '46', '48', '52', '56', '60', '64', '68', '72', '76', '80', '86', '92', '98'],
      fontNames: ['Arial', 'Arial Black', 'Comic Sans MS', 'Courier New', 'Helvetica', 'Impact', 'Tahoma', 'Times New Roman', 'Verdana'],
      // addDefaultFonts : true,
      // maximumImageFileSize : _self.maxImageSize,
      tableClassName: 'table table-bordered',
      insertTableMaxSize: {
        col: 10,
        row: 10,
      },
      toolbar: toolbarOptions,
      popover: {
        image: [
          ['image', ['resizeFull', 'resizeHalf', 'resizeQuarter', 'resizeNone']],
          ['float', ['floatLeft', 'floatRight', 'floatNone']],
          ['remove', ['removeMedia']]
        ],
        link: [
          ['link', ['linkDialogShow', 'unlink']]
        ],
        table: [
          ['add', ['addRowDown', 'addRowUp', 'addColLeft', 'addColRight']],
          ['delete', ['deleteRow', 'deleteCol', 'deleteTable']],
          ['tablerowcolor', ['setTableRowColor']],
          ['tablebordercolor', ['setTableBorder']],
          ['tablecellcolor', ['setTableCellColor']],
          ['cellVerticalAlightn', ['setCellVeticalAlign']],
          ['merge', ['jMerge']],
          ['style', ['jBackcolor', 'jBorderColor', 'jAlign']],
          ['info', ['jTableInfo']],
          // ['delete', ['jWidthHeightReset', 'deleteTable']],
        ],
      },
      buttons: {
        fontResizer: fontResizerBtn,
        setTableRowColor: rowcolorbtn,
        setTableBorder: borderColorBtn,
        setTableCellColor: cellColorBtn,
        setCellVeticalAlign: cellVerticalAlignBtn,
        titleBtn: createBuilderTitle,
        // truncate : truncateBtn,
        pageSetup: pageSetupBtn,
      },
      tabsize: 2,
      disableResizeEditor: true,
      blockquoteBreakingLevel: 2,
      dialogsInBody: true,
      dialogsFade: false,
      disableDragAndDrop: true,
      shortcuts: true,
      tabDisable: true,
      codeviewFilter: false,
      codeviewIframeFilter: true,
      toolbarPosition: 'top',
      spellCheck: true,
      disableGrammar: false,
      acceptImageFileTypes: "image/*",
      allowClipboardImagePasting: true,
      codemirror: {
        theme: 'blackboard',
        mode: "text/html",
        lineNumbers: true,
        tabMode: 'indent'
      },

      icons: {
        'align': customeIcons.alignjustify,
        'alignCenter': customeIcons.aligncenter,
        'alignJustify': customeIcons.alignjustify,
        'alignLeft': customeIcons.alignleft,
        'alignRight': customeIcons.alignright,
        'rowBelow': 'note-icon-row-below',
        'colBefore': 'note-icon-col-before',
        'colAfter': 'note-icon-col-after',
        'rowAbove': 'note-icon-row-above',
        'rowRemove': 'note-icon-row-remove',
        'colRemove': 'note-icon-col-remove',
        'indent': 'note-icon-align-indent',
        'outdent': 'note-icon-align-outdent',
        'arrowsAlt': customeIcons.fullScreen2,
        'bold': customeIcons.bold2,
        'caret': 'note-icon-caret',
        'circle': 'note-icon-circle',
        'close': 'note-icon-close',
        'code': 'note-icon-code',
        'eraser': customeIcons.clearFormat2,
        'floatLeft': 'note-icon-float-left',
        'floatRight': 'note-icon-float-right',
        'font': customeIcons.fontColor2,
        'frame': 'note-icon-frame',
        'italic': customeIcons.italic2,
        'link': customeIcons.link,
        'unlink': customeIcons.unlink,
        'magic': 'note-icon-magic',
        'menuCheck': 'note-icon-menu-check',
        'minus': customeIcons.pageBreak,
        'orderedlist': customeIcons.orderedlist,
        'pencil': 'note-icon-pencil',
        'picture': customeIcons.image2,
        'question': customeIcons.help,
        'redo': 'note-icon-redo',
        'rollback': 'note-icon-rollback',
        'square': 'note-icon-square',
        'strikethrough': customeIcons.strikethrough2,
        'subscript': customeIcons.subscript,
        'superscript': customeIcons.superscript,
        'table': customeIcons.table2,
        'textHeight': customeIcons.lineHeight2,
        'trash': 'note-icon-trash',
        'underline': customeIcons.underline2,
        'undo': 'note-icon-undo',
        'unorderedlist': customeIcons.unorderedlist,
        'video': 'note-icon-video',
        'rowcolor': customeIcons.rowcolor + 'Row Color',
        'cellcolor': customeIcons.cellColor + 'Cell Color',
        'bordercolor': customeIcons.tableBorder + 'Border',
      },

      callbacks: {
        onInit: function () {
          // Method to set CSS of HTML Elements Once Editor Load SuccessFully...
          setCSSAfterLoadEditor(note);
          _self.calculateRelatedListTable(note);
        },
        onBeforeCommand: null,
        onBlur: null,
        onBlurCodeview: null,
        onChange: function () {
          // function(contents, context, $editable)
          setFontResizerValue(note);
          _self.calculateRelatedListTable(note);
          _self.restrictLargeImageInsert(note);
          _self.editorDataChanges = true;
          // _self.setHeaderFooterMaxHeight(note);
        },
        onChangeCodeview: null,
        onDialogShown: null,
        onEnter: function (event) {
          _self.setHeaderFooterMaxHeight(note, event);
        },
        onFocus: null,
        onImageLinkInsert: null,
        onImageUpload: null,
        onImageUploadError: null,
        onKeydown: function (event) {
          _self.setHeaderFooterMaxHeight(note, event);
          preventPageBreakInHeaderFooter(note, event);
        },
        onKeyup: null,
        onMousedown: null,
        onMouseup: function () {
          setFontResizerValue(note);
          _self.setHeaderFooterMaxHeight(note);
        },
        onPaste: function () {
          // _self.setHeaderFooterMaxHeight(note);
        },
        onScroll: null,
      },

    });

    return true;
  } catch (error) {
    console.warn('error in editorConfig.initializeSummerNote : ', error.stack);
    return false;
  }
}