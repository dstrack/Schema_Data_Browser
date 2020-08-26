/*
Copyright 2019 Dirk Strack, Strack Software Development

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
"use strict";

function extraIsChanged () {
    return htmldb_ch;
}

function check_isChanged() {
    var hasChanged = false;
    var SEL_IGNORE_CHANGE = ".js-ignoreChange";

    function forEachPageItem( form$, callback, allElements ) {
        var processed = {};

        $( form$[0].elements ).each( function() {
            var el = this,
                name = el.name,
                type = el.type,
				id = el.id;

            if ( el.nodeName === "BUTTON" || type === "button" || type === "submit" || type === "reset" || !name ) {
                return;
            }
            // for checkboxes and radio groups there can be more than one element with the same name. The name is treated
            // as the item name and we only want to process an item once.
            if ( !allElements && processed[name] ) {
                return;
            }
            var val = $v(name) || $('input#'+id).val();
            console.log('PageItemName : ' + name + ' : ' + val);
            if ( apex.server.isValidPageItemName( name ) ) {
                // process page items including disabled or unchecked items
                processed[name] = 1;
                return callback( el, name, type );
            }
        } );
    }

    if ( apex.model ) {
        hasChanged = apex.model.anyChanges();
    }

    if ( !hasChanged ) {
        forEachPageItem( $( "#wwvFlowForm" ), function( el, name ) {
            // never check if disabled items have changed
            if ( el.disabled ) {
                return;
            }
            // if not flagged to ignore then check if it is changed
            if ( $( el ).closest( SEL_IGNORE_CHANGE ).length === 0 ) {
                if ( apex.item( name ).isChanged() ) {
                    hasChanged = true;
                    console.log('PageItemName :' + name + ' - is Changed!' );
                    return false; // found one change no need to check any more
                }
            }
        } );
    }
    if ( !hasChanged && extraIsChanged ) {
        hasChanged = extraIsChanged();
    }

    return hasChanged;
};

function align_report (align_str, offset, region) {
    var align_array = align_str.split(':');
    offset = typeof offset !== 'undefined' ? offset : 0;
    region = typeof region !== 'undefined' ? region : 'TABLE_DATA_VIEW';
    console.log('-- '+region+' setting report alignment');
    align_array.forEach(function (item, index) {
        if (index >= offset) {
            index = index - offset + 1;
            $('div#report_'+region+'.t-Report table.t-Report-report tbody tr td:nth-child('+index+')').prop("align",item);
            $('div#report_'+region+'.t-Report table.t-Report-report thead th:nth-child('+index+')').prop("align",item);
        }
    });
}
// call align_record_view($v('P32_LAYOUT_COLUMNS'));
function align_record_view (p_layout, region, id) {
    region = typeof region !== 'undefined' ? region : 'RECORD_VIEW';
    var layout = typeof p_layout !== 'undefined' ? p_layout-0 : 1;
    var width = (90/layout)+'%';
    var prefix = '';
    id = typeof id !== 'undefined' ? id : '';
    if (id.length > 0) {
    	prefix = 'div#'+id+' ';
    }
    switch(layout) {
      case 3:
        $(prefix+'div#report_'+region+' th[id="COLUMN_DATA3"]').css('width',width);
      case 2:
        $(prefix+'div#report_'+region+' th[id="COLUMN_DATA2"]').css('width',width);
      case 1:
        $(prefix+'div#report_'+region+' th[id="COLUMN_DATA1"]').css('width',width);
    }
}

function report_item_help (item_help_str, offset, region, id) {
    var align_array = item_help_str.split('|');
    var element;
    var prefix = '';
    offset = typeof offset !== 'undefined' ? offset : 0;
    region = typeof region !== 'undefined' ? region : 'TABLE_DATA_VIEW';
    id = typeof id !== 'undefined' ? id : '';
    if (id.length > 0) {
    	prefix = 'div#'+id+' ';
    }
    console.log('-- '+region+' setting report item help');
    align_array.forEach(function (item, index) {
        if (item.length > 0 && index >= offset) {
            index = index - offset + 1;
           	element = $(prefix+'div#report_'+region+'.t-Report table.t-Report-report thead:first-of-type th:nth-child(' + index + ').t-Report-colHead');
            element.find('.t-Button--helpButton').remove();
            element.append(item);
        }
    });
}

function report_item_sortable (region) {
    region = typeof region !== 'undefined' ? region : 'TABLE_DATA_VIEW';
    var page_id = $v('pFlowStepId');
    var v_order_msg = $v('P'+page_id+'_ORDER_MSG');
    if (v_order_msg.length > 0) {
        $('div#report_'+region+' th a[data-item]').attr("title", $v(v_order_msg));
    }
    // replace href # with void call
    $('div#report_'+region+' th a[data-item]').attr("href","javascript:void(0);");
    $('div#report_'+region+' th a[data-item]').wrap( '<span class="u-Report-sortHeading"></span>' );
}

// Ordering Columns are displayed with row mover buttons. When a row is moved with one of this buttons, 
// this function is called to update the hidden input field of that column.
// The Report should be ordered by the ordering column and 
// this function renumbers the rows starting with the smallest value of the visible array
function report_ordering_update (region) {
    region = typeof region !== 'undefined' ? region : 'TABLE_DATA_VIEW';
    var ordering_colum = $('div#report_'+region+'.t-Report table.t-Report-report tbody tr td:has(img[src*="arrow_down"]) input[type="hidden"]');
    var start = Number.MAX_VALUE;
    ordering_colum.each(function( index ) {
        var current = Number($(this).val());
      if (start > current) {
        start = current;
      }
    });
    if (! start || start === Number.MAX_VALUE) {
        start = 1;
    }
    ordering_colum.each(function( index ) {
      $(this).val(index + start);
    });
}

function scroll_DetailViewsList() {
    var xtop = $('div#RIGHT_CONTAINER div#DETAIL_VIEWS_LIST').offset().top;
    $('div#RIGHT_CONTAINER div.t-Region-body').scrollTop(xtop-150);
}

function check_form_validations(p_table_name, p_data_source)
{
    function Async_get_Message() {
        var gh = p;
        if (gh.readyState == 4) {
            var msg_array = gh.responseText.split('\n');
            msg_array.forEach(function (item, index) {
                var line_array = item.split('\t');
                var field_id = line_array[0];
                var message_text = line_array[1];
                if (typeof field_id !== 'undefined' && field_id.length > 0) {
                    var element = $('div#TABLE_DATA_VIEW :input#' + field_id);
                    if (element) {
                        $(element).addClass('apex-tabular-form-error');
                        $(element.parentNode).find('span.t-Form-error').remove();
                        $(element).after('<span class="t-Form-error" style="white-space: normal;">'+message_text+'</span>');
                    }
                }
            })
        }
    }
    var page_id = $v('pFlowStepId');
    p_data_source = typeof p_data_source !== 'undefined' ? p_data_source : 'TABLE';
    if (p_table_name.length > 0) {
        var get = new htmldb_Get(null,$v('pFlowId'),'APPLICATION_PROCESS=Form_Validation_Process',0);
        get.add('APP_PRO_TABLE_NAME', p_table_name);
        get.add('APP_PRO_DATA_SOURCE', p_data_source);
        get.GetAsync(Async_get_Message); 
    }
    return true;
}

function check_required_event(element) {
    var v_value = element.value;
    var v_message = 'Value is required.';
    if (v_value.length === 0) {
        // alert(l_Message); 
        $(element).addClass('apex-tabular-form-error');
        $(element.parentNode).find('span.t-Form-error').remove();
        $(element).after('<span class="t-Form-error" style="white-space: normal;">'+v_message+'</span>');
        return false;
    } else {
        $(element).removeClass('apex-tabular-form-error');
        $(element.parentNode).find('span.t-Form-error').remove();
        return true;
    }
}

function check_range_event(element, p_table_name) {
    function validate_form_checks(p_Column_Name, p_Column_Value, p_Key_Value)
    {
        function Async_get_Message() {
            function get_responseItemValue(p, index) {
                if (p.responseXML) {
                    var node = p.responseXML.getElementsByTagName("item")[index];
                    if (node && node.firstChild) {
                        return node.firstChild.nodeValue;
                    }
                }
                return '';
            }
            var gh = p;
            if (gh.readyState == 4) {
                var l_Message = get_responseItemValue(gh, 0);
                if (l_Message.length > 0) {
                    // alert(l_Message); 
                    $(element).addClass('apex-tabular-form-error');
                    $(element.parentNode).find('span.t-Form-error').remove();
                    $(element).after('<span class="t-Form-error" style="white-space: normal;">'+l_Message+'</span>');
                    return false;
                } else {
                    $(element).removeClass('apex-tabular-form-error');
                    $(element.parentNode).find('span.t-Form-error').remove();
                    return true;
                }
            }
        }
        var page_id = $v('pFlowStepId');
        var v_table_name = typeof p_table_name !== 'undefined' ? p_table_name : $v('P'+page_id+'_TABLE_NAME');
        if (p_Column_Value.length > 0 && v_table_name.length > 0) {
            var get = new htmldb_Get(null,$v('pFlowId'),'APPLICATION_PROCESS=Form_Checks_Process',0);
            get.add('APP_PRO_TABLE_NAME', v_table_name);
            get.add('APP_PRO_COLUMN_NAME', p_Column_Name);
            get.add('APP_PRO_COLUMN_VALUE', p_Column_Value);
            get.add('APP_PRO_KEY_VALUE', p_Key_Value);
            console.log('checking ' + v_table_name + '.' + p_Column_Name + ' : ' + p_Column_Value + ', Key_Value : ' + p_Key_Value);
            get.GetAsync(Async_get_Message); 
        }
    }

    var key_element = $(element).closest('tr').find('input.check_unique[name*=f][type="hidden"]');
    if (key_element.length === 0) {
        key_element = $(element).closest('table').find('input.check_unique[name*=f][type="hidden"]');
    }
    var key_value = (key_element.length > 0)? key_element[0].value : '';
    var column_name = $('label[for="'+element.id+'"]').first().text();
    var column_value = element.value;

    validate_form_checks(column_name, column_value, key_value);
}


function adjustTreeHeight() {
    // dynamic resize for the tree region 
    var container = $("div#TABLES_LIST div.t-Region-bodyWrap");
    if (container.length) {
        var divtop = container.offset().top;
        var treeheight = window.innerHeight - divtop - 10;
        treeheight = (treeheight > 300) ? treeheight : 300;
        container.height(treeheight);
        container.css('overflow','scroll');
    }
}

// adjust PREVIEW iframe to remove the scrollbars
function setIframeHeight(iframeId, pageid) 
{
    var iframeDoc;
    var iframeRef = document.getElementById(iframeId);
    try {
        iframeDoc = iframeRef.contentWindow.document.documentElement;  
    }
    catch(e){ 
        try { 
            iframeDoc = iframeRef.contentDocument.documentElement;  
        }
        catch(ee){   
        }  
    }
    if (iframeDoc) {
        var height = parseInt(iframeDoc.scrollHeight);
        var width = parseInt(iframeDoc.scrollWidth);
        if (height < 128) {
            height = 128;
        }
        if (width < 128) {
            width = 128;
        }
        iframeRef.height = height + 30;
        iframeRef.width = width + 30; 
    }
}


window.requestAnimFrame = (function(){
  return  window.requestAnimationFrame       ||
          window.webkitRequestAnimationFrame ||
          window.mozRequestAnimationFrame    ||
          function( callback ){
            window.setTimeout(callback, 1000 / 60);
          };
})();

var PaginationControl = (function (document) {
    function register_pagination (instance) {
    	var link, offset1, offset2;
        // keep current report pagination
        // split the url 
        var current_set = $('#' + instance.static_id + ' .t-Report-paginationText').html();
        if (typeof current_set !== 'undefined') {
            var current_ar = current_set.split(' ').filter(e => e !== "row(s)").filter(e => e !== "of").filter(e => e !== "-");
            instance.first_record = current_ar[0] - 0;
            instance.last_record  = current_ar[1] - 0;
            instance.max_record   = instance.last_record - instance.first_record+1;
            instance.fetched_recs = $v(instance.rows_item);
        
            link = $('div.t-Report-links a').attr('href');
            if (link) {
				offset1 = link.indexOf('"') + 1;
				offset2 = link.indexOf('"', offset1);
				instance.pag_checksum = link.substring(offset1, offset2);
            }
			if (! instance.pag_checksum) {
				link = $('div.t-Report-links a').attr('onclick');
				if (link) {
					offset1 = link.indexOf('"') + 1;
					offset2 = link.indexOf('"', offset1);
					instance.pag_checksum = link.substring(offset1, offset2);
            	}
			}
            console.log('-- current pagination is first : ' 
                + instance.first_record + ', last : ' 
                + instance.last_record + ', max : ' 
                + instance.max_record + ', ck : ' 
                + instance.pag_checksum);
        }
    }

    function refresh_current (instance) {
    	requestAnimFrame( function () {
            console.log('-- refresh current pagination is first : ' 
                + instance.first_record + ', last : ' 
                + instance.last_record + ', max : ' 
                + instance.max_record + ', ck : ' 
                + instance.pag_checksum);
			if (instance.pag_checksum) {
				apex.widget.report.paginate (
					$v(instance.region_id_item), 
					instance.pag_checksum, {
						min: instance.first_record,
						max: instance.max_record,
						fetched: instance.fetched_recs
					}
				);
			}
		});
    }
    // Init --------------------------------------------
    var curPagination = function (rows_item, region_id_item, static_id) {
        var instance = this;

        if (! $v(rows_item)) {
            console.log('PaginationControl.rows_item: Page Item '+ rows_item +' is missing!');
        }   
        if (! $v(region_id_item)) {
            console.log('PaginationControl.region_id_item: Page Item '+ region_id_item +' is missing!');
        }   
        this.rows_item = rows_item;
        this.region_id_item = region_id_item;
        this.static_id = static_id;

        // keep report pagination
        this.first_record = 0;
        this.last_record = 0;
        this.fetched_recs = $v(rows_item);
        this.max_record   = this.fetched_recs;
        this.pag_checksum = '';
        
        this.register_pagination = function () {
            return register_pagination(instance); 
        };
        this.refresh_current = function () {
            return refresh_current(instance); 
        };
    }

    return {
        curPagination : curPagination
    };
})(document);

/*
-- Example Init --
var curPagination = new PaginationControl.curPagination('P30_ROWS', 'P30_REP_REGION_ID', 'TABLE_DATA_VIEW');

-- Example register current --
curPagination.register_pagination();

-- Example refresh current --
curPagination.refresh_current();

*/

var NestedLinksControl = (function () {
    var This_Nested;
    var Last_Nested;
    var This_Nested_ID;
    var Last_Nested_ID;
    var alter_State;
    var Region;
    var Detail_Fkey_Column;
    var Detail_Fkey_Id;
    var Detail_Parent;
    var Detail_Table;

    function prep_nested_table (instance) {
        $s(instance.Detail_Fkey_Column, instance.This_Nested.attr('data-key-column'));
        $s(instance.Detail_Fkey_Id, instance.This_Nested.attr('data-key-value'));
        $s(instance.Detail_Table, instance.This_Nested.attr('data-table'));
        $s(instance.Detail_Parent, instance.This_Nested.attr('data-parent')); // trigger change
    }
	function close_this_nested_table (instance) {
        var ThisNestedSel = 'tr.nested_row#'+instance.This_Nested_ID;
        var ThisNested = $(ThisNestedSel);
        if (ThisNested.length) {
			ThisNested.remove();  // close this nested table 
			if (instance.alter_State) {
				instance.This_Nested.attr('data-state', 'closed');
			}
        }
	}
    function nested_target_id (target) {
        var target_id = target.attr('data-parent') 
            +'-'+target.attr('data-table')
            +'-'+target.attr('data-key-column')
            +'-'+target.attr('data-key-value');
        return target_id.replace(/\W/g, '_');
    }

	function remove_this_nested_table (instance) {
		$(instance.This_Nested).parents('table').first().find('tr.nested_row').remove();
	}
	
    function register_target(instance, p_Target) { 
        instance.This_Nested = $(p_Target);
        instance.This_Nested_ID = nested_target_id(instance.This_Nested);
        instance.alter_State = true;
    	var data_state = instance.This_Nested.attr('data-state');
        data_state = typeof data_state !== 'undefined' ? data_state : 'closed';

        console.log('### register_target for nested table link to table:'+instance.This_Nested_ID);
        remove_this_nested_table (instance);
        if (data_state === 'open') {
			instance.This_Nested.attr('data-state', 'closed');
		} else {
			prep_nested_table (instance); 
		}        
    }

    function register_pagination(instance, p_Target) { 
        instance.This_Nested = $(p_Target).parents('tr').prev().find('a.nested_view');
        instance.This_Nested_ID = nested_target_id(instance.This_Nested);
        instance.alter_State = false;
        console.log('### register_pagination for nested table link to table:'+instance.This_Nested_ID);
        prep_nested_table (instance);
	}

    function nested_target_changed(instance) {
        return ((instance.Last_Nested_ID === null || instance.Last_Nested_ID !== instance.This_Nested_ID)
        	&& $v(instance.Detail_Table).length > 0);
    }

    function show_nested_table (instance, callback) {
        close_this_nested_table (instance);
        if (instance.This_Nested) {
            console.log('after refresh nested view '+instance.Detail_Table);
            var target = instance.This_Nested;
            var target_id = nested_target_id(target);
            var vColSpan = $(target).closest("tr").find("td").length;
            var vClass = $(target).closest("td").attr("class");
            var vTR = $(target).closest("tr");
            var vReportHTML = $('#'+instance.Region).clone();
            vReportHTML = $(vReportHTML).removeAttr("id");
            vReportHTML = $(vReportHTML).css("display", "block");
            $(vTR).after(
            '<tr id="'+target_id+'" class="nested_row" style="display: none;">'
            + '<td class="'+vClass+'" colspan="'+vColSpan+'" style="padding: 8px; padding-left: 16px;">'
            + $('<div>').append($(vReportHTML)).html()
            + '</td></tr>');
            
            if (callback) {
                callback();
            }
            $('tr.nested_row').show(30, function(){
               instance.Last_Nested_ID = target_id;
               instance.Last_Nested = target;
               $(instance.Last_Nested).parents('table').first().find('tr a.nested_view').attr('data-state', 'closed');
               instance.Last_Nested.attr('data-state', 'open');
            }); 
        }
    }    
    // Init --------------------------------------------
    var Controller = function (p_Region, p_Detail_Fkey_Column, p_Detail_Fkey_Id, p_Detail_Parent, p_Detail_Table) {
        var instance = this;
		/*
        if (! $v(p_Detail_Fkey_Column)) {
            console.log('NestedLinksControl.Detail_Fkey_Column: Page Item '+ p_Detail_Fkey_Column +' is missing!');
        }   
        if (! $v(p_Detail_Fkey_Id)) {
            console.log('NestedLinksControl.Detail_Fkey_Id: Page Item '+ p_Detail_Fkey_Id +' is missing!');
        }   
        if (! $v(p_Detail_Parent)) {
            console.log('NestedLinksControl.Detail_Parent: Page Item '+ p_Detail_Parent +' is missing!');
        }   
        if (! $v(p_Detail_Table)) {
            console.log('NestedLinksControl.Detail_Table: Page Item '+ p_Detail_Table +' is missing!');
        }*/
        this.Region = p_Region;
        this.Detail_Fkey_Column = p_Detail_Fkey_Column;
        this.Detail_Fkey_Id = p_Detail_Fkey_Id;
        this.Detail_Parent = p_Detail_Parent;
        this.Detail_Table = p_Detail_Table;
        this.This_Nested = null;
        this.Last_Nested = null;
        this.This_Nested_ID = null;
        this.Last_Nested_ID = null;
        this.alter_State = false;
        this.register_target = function (p_Target) {
            return register_target(instance, p_Target); 
        };
        this.register_pagination = function (p_Target) {
            return register_pagination(instance, p_Target); 
        };
        this.nested_target_changed = function () {
            return nested_target_changed(instance); 
        };
        this.nested_target_id = function (target) {
            return nested_target_id(target); 
        };
        this.show_nested_table = function (target) {
            return show_nested_table(instance, target); 
        };
        this.close_nested_table = function () {
            return close_this_nested_table (instance); 
        };
    }

    return {
        Controller : Controller
    };
})();

