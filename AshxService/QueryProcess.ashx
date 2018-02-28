<%@ WebHandler Language="C#" Class="QueryProcess" %>

using System;
using System.Web;
using System.Collections;
using System.Reflection;
using System.Collections.Generic;
using System.Web.SessionState;
using System.Web.Caching;

using TF.CommonUtility;
using TF.Web.WebAPI;
public class QueryProcess : IHttpHandler, IRequiresSessionState
{

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        string action = context.Request.Params["DataType"].ToLower();
        string data = context.Request.Params["Data"];
        string result = "";
        APIItem item = GetApiFromCache(action);

        if (item != null)
        {
            try
            {
                //从bin目录加载程序集dll
                Assembly apiASM = Assembly.Load(item.AssemblyName);
                //从程序集获取类型
                Type apiType = apiASM.GetType(item.AssemblyName +"."+ item.TypeName, true, true);
                //创建实例
                object apiObject = Activator.CreateInstance(apiType, true);
                
                Type[] prmTypes = null;
                MethodInfo mi;
                object[] args = new object[] { data };
                prmTypes = new Type[] { typeof(string) };
                //获取方法，方法的参数都只有一个，类型是string，加上prmTypes是避免有函数重构的情况
                string strMethodName = item.MethodName;
                mi = apiType.GetMethod(strMethodName,BindingFlags.NonPublic|BindingFlags.Public|BindingFlags.IgnoreCase|BindingFlags.Instance ,null, prmTypes,null);
                
                //调用实例的方法，获取返回值
                object mOut = mi.Invoke(apiObject, args);
                //序列化json，这个部分可以根据自己项目实际情况，选用其他的方法格式化JSON
                //这里使用自定义日期格式，如果不使用的话，默认是ISO8601格式
                Newtonsoft.Json.Converters.IsoDateTimeConverter timeConverter = new Newtonsoft.Json.Converters.IsoDateTimeConverter();
                timeConverter.DateTimeFormat = "yyyy-MM-dd HH:mm:ss";
                result = Newtonsoft.Json.JsonConvert.SerializeObject(mOut, timeConverter);
            }
            catch (Exception ex)
            {
                LogClass.log("url:" + context.Request.Url.ToString());
                LogClass.log("dataType:" + action);
                LogClass.log("data:" + data);
                LogClass.logex(ex, "");
                result = "{\"Success\":\"0\",\"ResultText\":\"调用出现异常：" + ex.Message.Replace("\r\n", "") + "\"}";
            }
        }
        else
        {
            result = "{\"Success\":\"0\",\"ResultText\":\"接口不存在\"}";
        }
        LogClass.log(result);
        context.Response.Write(result);

    }

    /// <summary>
    /// 从缓存中获取接口定义
    /// </summary>
    /// <param name="strApiName">接口名称</param>
    /// <returns></returns>
    public APIItem GetApiFromCache(string strApiName)
    {
        APIItem item = null;
        Cache cache = HttpRuntime.Cache;
        List<APIItem> items = (List < APIItem >) cache.Get("apilist");
        if (items == null)
        {
            ApiManager manager=new ApiManager();
            items = manager.GetApiList();
        }
        item = GetApiByName(items, strApiName);
        
        return item;
    }
    /// <summary>
    /// 根据接口名称，从接口定义列表中获取指定的接口定义
    /// </summary>
    /// <param name="items">接口定义列表</param>
    /// <param name="strApiName">接口名称</param>
    /// <returns></returns>
    public APIItem GetApiByName(List<APIItem> items, string strApiName)
    {
        APIItem item = null;
        if (items != null)
        {
            foreach (APIItem api in items)
            {
                if (api.APIName.ToLower().Equals(strApiName))
                {
                    item = api;
                    break;
                }
            }
        }
        return item;
    }
    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
}
   