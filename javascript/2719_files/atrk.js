var iu='http://certify.alexametrics.com/atrk.gif?';
function _atrk_account()
{
try{return '&account='+_atrk_acct;}
catch(e){}
return '&account=';
}
function _atrk_gen_url()
{
try{
var i,ua=new Array(),up=["random_number","jsv","user_cookie","sess_cookie","host_url","ref_url","cookie_enabled","java_enabled","screen_params","flashver","time","title"];
for(i in up)
{
try
{f=up[i]; ua.push(f+'='+eval("_atrk_"+f+"()"));}
catch(e){}
}
return iu+ua.join('&')+_atrk_options()+_atrk_account();}catch(e){return iu+_atrk_account()}
}
function atrk()
{
var i=new Image(1,1);
i.alt='alexametrics';
i.src=_atrk_gen_url();
i.onload=function(){_atrk_jsv();};
}
function _atrk_dom(){
h=window.location.host;try{return  _atrk_opts.domain;}catch(e){try{h=document.domain;}catch(e){};return(h.substr(0,4)=="www."?h.substr(4):h);}
}
function _atrk_ts(s)
{
return s.replace(/\s+$/g,'');
}
function _atrk_sbc(n,v,ex)
{
var e=new Date(),d=_atrk_dom(),p="/";
e.setTime(e.getTime()+ex*1000);
document.cookie=n+"="+escape(v)+(ex?("; expires="+e.toGMTString()):"")+((d&&d.length>0)?("; domain=."+d):"")+"; path=/";
}
function _atrk_gbc(n)
{
var dc=document.cookie,p=n+"=",b=dc.indexOf("; "+p),e;
if(b==-1){b=dc.indexOf(p);if(b!=0)return null;}else{b+=2;}
e=dc.indexOf(";",b);
if(e==-1)
{
e=dc.length;
}
return _atrk_ue(dc.substring(b+p.length,e));
}
function _atrk_ue(s)
{
try{return encodeURIComponent(s);}
catch(e){return escape(s);}
}
function _atrk_jsv()
{return "20090615";}
function _atrk_random_number()
{
return Math.round(Math.random()*21474836747);
}
function _atrk_gc(cn,dv,sn,ex)
{
var tc="",ws=0;
try
{tc=_atrk_gbc(cn);}
catch(e){}
if(tc==null||tc.length==0)
{tc=dv;ws=1;}
_atrk_sbc(cn,tc,ex);
return tc+"&"+sn+"_flag="+ws;
}
function _atrk_muc(){
return _atrk_r()+_atrk_r()+(new Date().getTime().toString(16))+_atrk_r()+_atrk_r() ;}
function _atrk_r() {
return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
}
var user_cookie_v=_atrk_muc();
function _atrk_user_cookie()
{
return _atrk_gc('__auc',user_cookie_v,"user_cookie",366*24*60*60 );
}
function _atrk_sess_cookie()
{
return _atrk_gc('__asc',user_cookie_v,"sess_cookie",30*60);
}
function _atrk_host_url()
{
try{return _atrk_ue(window.location.href);}
catch(e){}
return '';
}
function _atrk_ref_url()
{
try{return _atrk_ue(document.referrer);}
catch(e){}
return '';
}
function _atrk_cookie_enabled()
{
if (navigator&&(typeof navigator.cookieEnabled!=undefined))
{return navigator.cookieEnabled?'1':'0';}
return '';
}
function _atrk_java_enabled()
{
if(navigator&&(typeof navigator.javaEnabled!=undefined))
{return navigator.javaEnabled()?'1':'0';}
return '';
}
function _atrk_screen_params()
{
try{return screen.width+'x'+screen.height+'x'+screen.colorDepth;}
catch(e){}
return '';
}
function _atrk_time()
{
i=new Date();
return i.getTime()+'&time_zone_offset='+i.getTimezoneOffset();
}
function _atrk_options()
{
var oa=new Array();
try{
for (var k in _atrk_opts)
{
if (typeof _atrk_opts[k]!='string')
{continue;}
if (k=='atrk_acct')
{_atrk_acct=_atrk_opts[k];}
else
{oa.push(k+'='+_atrk_ue(_atrk_opts[k]));}
}
return '&'+oa.join('&');}
catch(e){}
return '';
}
function _atrk_title()
{
return _atrk_ue(document?document.title:"");
}
function _atrk_flashver()
{
var sw="ShockwaveFlash.ShockwaveFlash",t="$version",a,e,st,v,_p=navigator.plugins;
if(_p&& _p.length > 0){
sw="Shockwave Flash";
v=_p[sw+" 2.0"];
v=v?v:_p[sw];
if(v){
st=v.description;
st=st.split(" ");
a=st[2].split(".");
v=st[3];
v=v?v:st[4];
if(v){
if(v[0]=="d"){
v=v.substring(1);}
else if(v[0]=="r"){
v=v.substring(1);
e=v.indexOf("d");
v=(e>0?v.substring(0,e):v);}}
return [a[0],a[1],v].join(".");}}
else{
var ver=[7,6,3,2];
for(v in ver){
v=ver[v];
try{
st=v<3?sw:sw+"."+v;
a=new ActiveXObject(st);
if(v==6){
try{a.AllowScriptAccess="always";}
catch(e){return "6.0.21.0";}}
if(v==3){
try{return a.GetVariable(t).split(" ")[1].split(",").join(".");}
catch(e){return "3.0.18.0";}}
if(v==2){return "2.0.0.11";}
return a.GetVariable(t).split(" ")[1].split(",").join(".");}
catch(e){}}}
return "XX.XX";
}
function gen_url(){return _atrk_gen_url()}
