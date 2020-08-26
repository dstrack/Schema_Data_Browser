/* begin htmldb_Get */
/**
 * @constructor
 * @param {Dom node | String} [obj] object to put in the partial page
 * @param {String} [flow] flow id
 * @param {String} [req] request value
 * @param {String} [page] page id
 * @param {String} [instance] instance
 * @param {String} [proc] process to call
 * @param {String} [queryString] hodler for quesry string
 *
 * */
function htmldb_Get(obj,flow,req,page,instance,proc,queryString) {
    /* setup variables */
    this.obj         = $x(obj);                              // object to put in the partial page
    this.proc        = (!!proc) ? proc : 'wwv_flow.show';    // proc to call
    this.flow        = (!!flow) ? flow : $v('pFlowId');      // flowid
    this.request     = (!!req)  ? req : '';                  // request
    this.page        = (!!page) ? page : '0';
    this.queryString = (!!queryString) ? queryString : null; // holder for passing in f? syntax

    this.params   = '';   // holder for params
    this.response = '';   // holder for the response
    this.base     = null; // holder fot the base url
    this.syncMode     = false;
    // declare methods
    this.addParam     = htmldb_Get_addParam;
    this.add          = htmldb_Get_addItem;
    this.getPartial   = htmldb_Get_trimPartialPage;
    /**
     * function return the full response
     * */
    this.getFull      = function(obj){
        var result;
        var node;
        if (obj){this.obj = $x(obj);}
        if (this.obj){
            if(this.obj.nodeName == 'INPUT'){
                this.obj.value = this.response;
            }else{
                if(document.all){
                    result = this.response;
                    node = this.obj;
                    setTimeout(function() {htmldb_get_WriteResult(node, result)},100);
                }else{
                    $s(this.obj,this.response);
                }
            }
        }
        return this.response;
    } ;

    /**
     * @param {Dom Node | String | Array | Dom Array | String id}[]
     * @return *
     * */
    this.get          = function(mode,startTag,endTag){
        var p;
        try {
            p = new XMLHttpRequest();
        } catch (e) {
            p = new ActiveXObject("Msxml2.XMLHTTP");
        }
        try {
            p.open("POST", this.base, this.syncMode);
            p.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
            p.send(this.queryString == null ? this.params : this.queryString );
            this.response = p.responseText;
            if (this.node){this.replaceNode(p.responseXML);}
            if ( mode == null || mode =='PPR' ) {
                return this.getPartial(startTag,endTag);
            } if ( mode == "XML" ) {
                return p.responseXML;
            } else {
                return this.getFull();
            }

        } catch (e) {
            return;
        }
    };

    this.url          = htmldb_Get_getUrl;
    this.escape       = htmldb_Get_escape;
    this.clear        = htmldb_Get_clear;
    this.sync         = htmldb_Get_sync;
    this.setNode      = setNode;
    this.replaceNode  = replaceNode;

    // setup the base url
    var u = (window.location.href.indexOf("?") > 0) ? window.location.href.substring(0,window.location.href.indexOf("?")) : window.location.href;
    this.base = u.substring(0,u.lastIndexOf("/"));

    if (!this.proc){this.proc = u.substring(u.lastIndexOf("/")+1);}

    this.base = this.base +"/" + this.proc;

    // grab the instance form the page form
    if(instance==null||instance==""){
        this.instance = $v('pInstance');
    }else{
        this.instance = instance;
    }

    // finish setiing up the base url and params
    if ( ! queryString ) {
        this.addParam('p_request',     this.request) ;
        this.addParam('p_instance',    this.instance);
        this.addParam('p_flow_id',     this.flow);
        this.addParam('p_flow_step_id',this.page);
    }

    function setNode(id) {
        this.node = $x(id);
    }
    function replaceNode(newNode){
        var i;
        for(i=this.node.childNodes.length-1;i>=0;i--){
            this.node.removeChild(this.node.childNodes[i]);
        }
        this.node.appendChild(newNode);
    }
}
function htmldb_Get_sync(s){
    this.syncMode=s;
}

function htmldb_Get_clear(val){
    this.addParam('p_clear_cache',val);
}

//
// return the queryString
//
function htmldb_Get_getUrl(){
    return this.queryString == null ? this.base +'?'+ this.params : this.queryString;
}

function htmldb_Get_escape(val){
    // force to be a string
    val = val + "";
    val = val.replace(/\%/g, "%25");
    val = val.replace(/\+/g, "%2B");
    val = val.replace(/\ /g, "%20");
    val = val.replace(/\./g, "%2E");
    val = val.replace(/\*/g, "%2A");
    val = val.replace(/\?/g, "%3F");
    val = val.replace(/\\/g, "%5C");
    val = val.replace(/\//g, "%2F");
    val = val.replace(/\>/g, "%3E");
    val = val.replace(/\</g, "%3C");
    val = val.replace(/\{/g, "%7B");
    val = val.replace(/\}/g, "%7D");
    val = val.replace(/\~/g, "%7E");
    val = val.replace(/\[/g, "%5B");
    val = val.replace(/\]/g, "%5D");
    val = val.replace(/\`/g, "%60");
    val = val.replace(/\;/g, "%3B");
    val = val.replace(/\?/g, "%3F");
    val = val.replace(/\@/g, "%40");
    val = val.replace(/\&/g, "%26");
    val = val.replace(/\#/g, "%23");
    val = val.replace(/\|/g, "%7C");
    val = val.replace(/\^/g, "%5E");
    val = val.replace(/\:/g, "%3A");
    val = val.replace(/\=/g, "%3D");
    val = val.replace(/\$/g, "%24");
    //val = val.replace(/\"/g, "%22");
    return val;
}
// Simple function to add name/value pairs to the url
function htmldb_Get_addParam(name,val){
    if ( this.params == '' ) {
        this.params =  name + '='+ ( val != null ? this.escape(val)  : '' );
    }
    else {
        this.params = this.params + '&'+ name + '='+ ( val != null ? this.escape(val)  : '' );
    }
}
/** Simple function to add name/value pairs to the url */
function htmldb_Get_addItem(name,value){
    this.addParam('p_arg_names',name);
    this.addParam('p_arg_values',value);
}
/** funtion strips out the PPR sections and returns that */
function htmldb_Get_trimPartialPage(startTag,endTag,obj) {
    if(obj) {this.obj = $x(obj);}
    if(!startTag){startTag = '<!--START-->'}
    if(!endTag){endTag  = '<!--END-->'}
    var start = this.response.indexOf(startTag);
    var result;
    var node;
    if(start>0){
        this.response  = this.response.substring(start+startTag.length);
        var end   = this.response.indexOf(endTag);
        this.response  = this.response.substring(0,end);
    }
    if(this.obj){
        if(document.all){
            result = this.response;
            node = this.obj;
            setTimeout(function() {htmldb_get_WriteResult(node, result)},100);
        }else{
            $s(this.obj,this.response);
        }
    }
    return this.response;
}

function htmldb_get_WriteResult(node, result){
    $s(node,result);
}


/**
 * Adds asynchronous AJAX to the {@link htmldb_Get} object.
 *
 * @param {function} pCallback Function that you want to call when the xmlhttp state changes
 *                             in the function specified by pCallback. The xmlhttp object can be referenced by declaring
 *                             a parameter, for example pResponse in your function.
 * @extends htmldb_Get
 */
htmldb_Get.prototype.GetAsync = function(pCallback){
    var lRequest;
    try{
        lRequest = new XMLHttpRequest();
    }catch(e){
        lRequest = new ActiveXObject("Msxml2.XMLHTTP");
    }
    try {
        lRequest.open("POST", this.base, true);
        if (lRequest) {
            lRequest.onreadystatechange = function(){
                // for backward compatibility we will also assign the request to the global variable p
                p = lRequest;
                pCallback(lRequest);
            };
            lRequest.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
            lRequest.send(this.queryString == null ? this.params : this.queryString );
            return lRequest;
        }
    }catch(e){
        return false;
    }
};

htmldb_Get.prototype.AddArray=function(pArray,pFnumber){
    var lFName = 'f';
    pFnumber = $nvl(pFnumber,1);
    if(pFnumber<10){lFName+='0'+pFnumber}else{lFName+=pFnumber}
    for(var i=0,len=pArray.length;i<len;i++){this.addParam(lFName,pArray[i]);}
    return this;
};

htmldb_Get.prototype.AddArrayItems=function(pArray,pFnumber){
    var lFName = 'f';
    pFnumber = $nvl(pFnumber,1);
    if(pFnumber<10){lFName+='0'+pFnumber}else{lFName+=pFnumber}
    for(var i=0,len=pArray.length;i<len;i++){this.addParam(lFName,$nvl($v(pArray[i])),'');}
    return this;
};

htmldb_Get.prototype.AddNameValue=function(pName,pValue,pFnumber){
    var pFnumber2;
    var lFName = 'f';
    var lFName2 = 'f';
    pFnumber = $nvl(pFnumber,1);
    pFnumber2 = pFnumber + 1;
    if(pFnumber<10){
        lFName+='0'+pFnumber}
    else{
        lFName+=pFnumber}
    if(pFnumber2<10){
        lFName2+='0'+pFnumber2;}
    else{
        lFName2+=pFnumber2;}
    this.addParam(lFName,pName);
    this.addParam(lFName2,$nvl(pValue),'');
    return this;
};

htmldb_Get.prototype.AddArrayItems2=function(pArray,pFnumber,pKey){
    var i, len, lTest, pFnumber2;
    var lFName = 'f';
    var lFName2 = 'f';
    pFnumber = $nvl(pFnumber,1);
    pFnumber2 = pFnumber + 1;
    if(pFnumber<10){
        lFName+='0'+pFnumber
    }else{
        lFName+=pFnumber
    }
    if(pFnumber2<10){
        lFName2+='0'+pFnumber2;
    }else{
        lFName2+=pFnumber2;
    }

    for(i=0,len=pArray.length;i<len;i++){
        lTest = $x(pArray[i]);
        if(lTest && lTest.id.length != 0){
            if (pKey) {
                this.addParam(lFName, apex.jQuery(lTest).attr(pKey));
            } else {
                this.addParam(lFName, lTest.id);
            }
        }
    }
    for(i=0,len=pArray.length;i<len;i++){
        lTest = $x(pArray[i]);
        if(lTest && lTest.id.length != 0){
            this.addParam(lFName2,$nvl($v(lTest)),'');
        }
    }

    return this;
};

htmldb_Get.prototype.AddArrayClob=function(pText,pFnumber){
    var lArray = $s_Split(pText,4000);
    this.AddArray(lArray,pFnumber);
    return this;
};

htmldb_Get.prototype.AddPageItems = function(pArray){
    for(var i=0,len=pArray.length;i<len;i++){
        if($x(pArray[i])){this.add($x(pArray[i]).id,$v(pArray[i]));}
    }
};

htmldb_Get.prototype.AddGlobals=function(p_widget_mod,p_widget_action,p_widget_action_mod,p_widget_num_return,x01,x02,x03,x04,x05,x06,x07,x08,x09,x10){
    this.addParam('p_widget_mod',p_widget_mod);
    this.addParam('p_widget_action',p_widget_action);
    this.addParam('p_widget_action_mod',p_widget_action_mod);
    this.addParam('p_widget_num_return',p_widget_num_return);
    this.addParam('x01',x01);
    this.addParam('x02',x02);
    this.addParam('x03',x03);
    this.addParam('x04',x04);
    this.addParam('x05',x05);
    this.addParam('x06',x06);
    this.addParam('x07',x07);
    this.addParam('x08',x08);
    this.addParam('x09',x09);
    this.addParam('x10',x10);
    return this;
};

/**
 * @function
 * Post Large Strings
 * */
function $a_PostClob(pThis,pRequest,pPage,pReturnFunction){
    var get = new htmldb_Get(null,$v('pFlowId'),pRequest,pPage, null, 'wwv_flow.accept');
    get.AddArrayClob($x(pThis).value,1);
    get.GetAsync(pReturnFunction);
    get=null;
}

/**
 * @function
 * Get Large Strings
 * */
function $a_GetClob(pRequest,pPage,pReturnFunction){
    var get = new htmldb_Get(null,$v('pFlowId'),pRequest,pPage, null,'wwv_flow.accept');
    get.GetAsync(pReturnFunction);
}

/**
 * @ignore
 * */
function ob_PPR_TAB(l_URL){
    // This function is only for use in the SQL Workshop Object Browser!
    top.gLastTab = l_URL;
    var lBody = document.body;
    var http = new htmldb_Get(lBody,null,null,null,null,'f',l_URL.substring(2));
    http.get(null,'<body  style="padding:10px;">','</body>');
}

/* end htmldb_Get */

/**
 * Gets PDF src XML
 * */
function htmldb_ExternalPost(pThis,pRegion,pPostUrl){
    var pURL = 'f?p='+$x('pFlowId').value+':'+$x('pFlowStepId').value+':'+$x('pInstance').value+':FLOW_FOP_OUTPUT_R'+pRegion;
    document.body.innerHTML = document.body.innerHTML + '<div style="display:none;" id="dbaseSecondForm"><form id="xmlFormPost" action="' + pPostUrl + '?ie=.pdf" method="post" target="pdf"><textarea name="vXML" id="vXML" style="width:500px;height:500px;"></textarea></form></div>';
    var l_El = $x('vXML');
    var get = new htmldb_Get(l_El,null,null,null,null,'f',pURL.substring(2));
    get.get();
    get = null;
    setTimeout( function() {
        $x("xmlFormPost").submit();
    },10 );
}

/**
 * @namespace apex.ajax
 * @deprecated Use apex.server
 */
apex.ajax = {
    /**
     * @param {?} pReturn
     * */
    clob : function (pReturn){
        var that = this;
        this.ajax = new htmldb_Get(null,$x('pFlowId').value,'APXWGT',0);
        this.ajax.addParam('p_widget_name','apex_utility');
        this.ajax.addParam('x04','CLOB_CONTENT');
        this._get = _get;
        this._set = _set;
        this._return = !!pReturn?pReturn:_return;

        function _get(pValue){
            that.ajax.addParam('x05','GET');
            that.ajax.GetAsync(that._return);
        }
        function _set(pValue){
            that.ajax.addParam('x05','SET');
            that.ajax.AddArrayClob(pValue,1);
            that.ajax.GetAsync(that._return);
        }
        function _return() {
            if(p.readyState == 1){
            }else if(p.readyState == 2){
            }else if(p.readyState == 3){
            }else if(p.readyState == 4){
                return p;
            }else{return false;}
        }
    },
    /**
     * @param {?} pReturn
     * */
    test : function (pReturn){
        var that = this;
        this.ajax = new htmldb_Get(null,$x('pFlowId').value,'APXWGT',0);
        this.ajax.addParam('p_widget_name','apex_utility');
        this._get = _get;
        this._set = _set;
        this._return = !!pReturn?pReturn:_return;

        function _get(pValue){
            that.ajax.GetAsync(that._return);
        }
        function _set(pValue){}
        function _return(pValue){}
    },
    /**
     * @param {?} pWidget
     * @param {?} pReturn
     * */
    widget : function (pWidget,pReturn){
        var that = this;
        this.ajax = new htmldb_Get(null,$x('pFlowId').value,'APXWGT',0);
        this.ajax.addParam('p_widget_name',pWidget);
        this._get = _get;
        this._set = _set;
        this._return = !!pReturn?pReturn:_return;

        function _get(pValue){
            that.ajax.GetAsync(that._return);
        }
        function _set(pValue){}
        function _return(pValue){}
    },
    /**
     * @param {?} pWidget
     * @param {?} pReturn
     * @deprecated Use apex.server.process
     * */
    ondemand : function (pWidget,pReturn){
        var that = this;
        this.ajax = new htmldb_Get(null,$x('pFlowId').value,'APPLICATION_PROCESS='+pWidget,0);
        this._get = _get;
        this._set = _set;
        this._return = !!pReturn?pReturn:_return;

        function _get(pValue){
            that.ajax.GetAsync(that._return);
        }
        function _set(pValue){}
        function _return(pValue){}
    },
    /**
     * @param {?} pUrl
     * @param {?} pReturn
     * */
    url : function (pUrl,pReturn){
        var that = this;
        this.ajax = new htmldb_Get(null,null,null,null,null,'f',pUrl);
        this._get = _get;
        this._set = _set;
        this._return = !!pReturn?pReturn:_return;

        function _get(pValue){
            that.ajax.GetAsync(that._return);
        }
        function _set(pValue){}
        function _return(pValue){}
    }

};
