//
//  ViewController.m
//  XCWKWebViewDemo
//
//  Created by Cai,Tengyuan on 2017/9/19.
//  Copyright © 2017年 Cai,Tengyuan. All rights reserved.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>

@interface ViewController () <WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIButton *btn;

@end

@implementation ViewController

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    // 视图即将消失的时候, 移除 防止循环引用
    [_webView.configuration.userContentController removeAllUserScripts];
    // self-->webView-->configuration-->userContentControll-->self 循环引用
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initWKWebView];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(150, 50, 100, 50);
    [btn setTitle:@"自定义JS" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor grayColor]];
    [btn addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
    _btn = btn;
    [self.view addSubview:btn];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initWKWebView{
    // 进行配置控制器
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    // 实例化对象
    configuration.userContentController = [[WKUserContentController alloc] init];
    
    // 调用js方法, js方法定义中的字段 window.webkit.messageHandlers.<自定义字段>.postMessage(<回传数据>);
    [configuration.userContentController addScriptMessageHandler:self name:@"Share"];
    [configuration.userContentController addScriptMessageHandler:self name:@"Location"];
    [configuration.userContentController addScriptMessageHandler:self name:@"Color"];
    [configuration.userContentController addScriptMessageHandler:self name:@"GoBack"];
    [configuration.userContentController addScriptMessageHandler:self name:@"Pay"];
    
    // 注入一段自定义的js代码到网页中
    NSString *jsStr = @"function myfunction(){var x=5+1; alert(x); window.webkit.messageHandlers.hello.postMessage(x);}";
    //WKUserScriptInjectionTimeAtDocumentEnd为网页加载完成时注入
    WKUserScript *script = [[WKUserScript alloc] initWithSource:jsStr injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [configuration.userContentController addUserScript:script];
    [configuration.userContentController addScriptMessageHandler:self name:@"hello"];
    
    _webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:configuration];
    
    NSString *urlStr = [[NSBundle mainBundle] pathForResource:@"index.html" ofType:nil];
    NSURL *fileURL = [NSURL fileURLWithPath:urlStr];
    [_webView loadFileURL:fileURL allowingReadAccessToURL:fileURL];
    
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    
    [self.view addSubview:_webView];
}

- (void)btnClick{
    // 执行注入的js代码
    [_webView evaluateJavaScript:@"myfunction()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"result=%@, Error=%@", result, error);
    }];
}

#pragma mark -- WKScriptMessageHandlerDelegate
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    NSLog(@"body:%@",message.body);
    if ([message.name isEqualToString:@"Location"]) {
        NSLog(@"获取位置");
        [self getLocation];
    } else if ([message.name isEqualToString:@"Share"]) {
        [self shareWithParams:message.body];
    } else if ([message.name isEqualToString:@"Color"]) {
        [self changeBGColor:message.body];
    }  else if ([message.name isEqualToString:@"GoBack"]) {
        NSLog(@"goBack");
//        [self goBack];
    }else if ([message.name isEqualToString:@"Pay"]){
        [self payWithParams:message.body];
    }else if ([message.name isEqualToString:@"hello"]){
        NSLog(@"自定义的hello");
    }
}

#pragma mark - private method
//这是获取位置信息,结果返回js
- (void)getLocation
{
    // 获取位置信息
    // 将结果返回给js
    NSString *jsStr = [NSString stringWithFormat:@"setLocation('%@')",@"广东省深圳市南山区学府路XXXX号"];
    [self.webView evaluateJavaScript:jsStr completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@----%@",result, error);
    }];
    
}

- (void)shareWithParams:(NSDictionary *)tempDic
{
    if (![tempDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    NSString *title = [tempDic objectForKey:@"title"];
    NSString *content = [tempDic objectForKey:@"content"];
    NSString *url = [tempDic objectForKey:@"url"];
    // 在这里执行分享的操作
    
    // 将分享结果返回给js
    NSString *jsStr = [NSString stringWithFormat:@"shareResult('%@','%@','%@')",title,content,url];
    [self.webView evaluateJavaScript:jsStr completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@----%@",result, error);
    }];
}

- (void)changeBGColor:(NSArray *)params
{
    if (![params isKindOfClass:[NSArray class]]) {
        return;
    }
    
    if (params.count < 4) {
        return;
    }
    
    CGFloat r = [params[0] floatValue];
    CGFloat g = [params[1] floatValue];
    CGFloat b = [params[2] floatValue];
    CGFloat a = [params[3] floatValue];
    
    self.btn.backgroundColor = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
    self.webView.backgroundColor = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

#pragma mark 支付部分,有完整的JS调用的方法还有返回的方法
- (void)payWithParams:(NSDictionary *)tempDic
{
    if (![tempDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    //获取网页传回来的数据
    NSString *orderNo = [tempDic objectForKey:@"order_no"];
    long long amount = [[tempDic objectForKey:@"amount"] longLongValue];
    NSString *subject = [tempDic objectForKey:@"subject"];
    NSString *channel = [tempDic objectForKey:@"channel"];
    NSLog(@"%@---%lld---%@---%@",orderNo,amount,subject,channel);
    
    // 支付操作
    
    // 将支付结果返回给js
    //    这里的payResult()是JS的语言
    NSString *jsStr = [NSString stringWithFormat:@"payResult('%@')",@"支付成功"];
    [self.webView evaluateJavaScript:jsStr completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@----%@",result, error);
        //        NSLog(@"%@",result);
    }];
}

//- (void)goBack
//{
//    [self.webView goBack];
//    
//}

#pragma mark -- WKUIDelegate
// 提醒 对应js的Alert方法
/**
 *  web界面中有弹出警告框时调用
 *
 *  @param webView           实现该代理的webview
 *  @param message           警告框中的内容
 *  @param frame             主窗口
 *  @param completionHandler 警告框消失调用
 */
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提醒" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 确认提交 对应js的confirm方法
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    NSLog(@"%s",__FUNCTION__);
    // 按钮
    UIAlertAction *alertActionCancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // 返回用户选择的信息
        completionHandler(NO);
    }];
    UIAlertAction *alertActionOK = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }];
    // alert弹出框
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:alertActionCancel];
    [alertController addAction:alertActionOK];
    [self presentViewController:alertController animated:YES completion:nil];

}

// 文本框输入 对应js的prompt方法
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    NSLog(@"%s",__FUNCTION__);
    // alert弹出框
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:nil preferredStyle:UIAlertControllerStyleAlert];
    // 输入框
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = defaultText;
    }];
    // 确定按钮
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 返回用户输入的信息
        UITextField *textField = alertController.textFields.firstObject;
        completionHandler(textField.text);
    }]];
    // 显示
    [self presentViewController:alertController animated:YES completion:nil];

}

#pragma mark -- WKNavigationDelegate
/* 1.在发送请求之前，决定是否跳转  */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    NSLog(@"%s", __func__);
    // 必须调用 否则崩溃 允许跳转, 类似于 webView:shouldStartLoadWithRequest 返回 YES
    decisionHandler(WKNavigationActionPolicyAllow);
}

/* 2.页面开始加载 */
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    NSLog(@"%s", __func__);
}

/* 3.在收到服务器的响应头，根据response相关信息，决定是否跳转。 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    NSLog(@"%s", __func__);
    // 必须调用 否则崩溃, 允许跳转, 类似于 webView:shouldStartLoadWithRequest 返回 YES
    decisionHandler(WKNavigationResponsePolicyAllow);
}

/* 4.开始获取到网页内容时返回，需要注入JS，在这里添加 */
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    NSLog(@"%s", __func__);
}

/* 5.页面加载完成之后调用 */
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    NSLog(@"%s", __func__);
}

/* error - 页面加载失败时调用, 提交 navigation错误的时候调用 */
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    NSLog(@"%s", __func__);
}

/* error - 页面加载失败时调用, 加载数据错误时调用 */
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    NSLog(@"%s", __func__);
}

/* 其他 - 处理服务器重定向Redirect */
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation{
    NSLog(@"%s", __func__);
    
}
/*其他--解决webView白屏问题*/
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView{
    NSLog(@"%s", __func__);
    [webView reload];
}


@end
