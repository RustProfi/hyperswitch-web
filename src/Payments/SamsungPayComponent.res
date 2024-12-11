@react.component
let make = (~sessionObj: option<JSON.t>, ~walletOptions) => {
  open Utils
  open RecoilAtoms

  let url = RescriptReactRouter.useUrl()
  let isSamsungPayReady = Recoil.useRecoilValueFromAtom(isSamsungPayReady)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(areOneClickWalletsRendered)
  let {publishableKey, iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let status = CommonHooks.useScript("https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js")
  let isWallet = walletOptions->Array.includes("samsung_pay")
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Samsungpay)

  let (_, _, _, _, heightType) = options.wallets.style.height
  let height = switch heightType {
  | SamsungPay(val) => val
  | _ => 48
  }

  let getSamsungPaymentsClient = _ =>
    SamsungPayType.samsung({
      environment: "PRODUCTION",
    })

  let onSamsungPaymentButtonClick = _ => {
    loggerState.setLogInfo(
      ~value="SamsungPay Button Clicked",
      ~eventName=SAMSUNG_PAY,
      ~paymentMethod="SAMSUNG_PAY",
    )
    SamsungPayHelpers.handleSamsungPayClicked(
      ~sessionObj=sessionObj->Option.getOr(JSON.Encode.null)->getDictFromJson,
      ~componentName,
      ~iframeId,
      ~readOnly=options.readOnly,
    )
  }

  let buttonStyle = {
    "onClick": onSamsungPaymentButtonClick,
    "buttonStyle": "black",
    "type": "buy",
  }->Identity.anyTypeToJson

  let addSamsungPayButton = _ => {
    let paymentClient = getSamsungPaymentsClient()
    let button = paymentClient.createButton(buttonStyle)
    let spayWrapper = GooglePayType.getElementById(GooglePayType.document, "samsungpay-container")
    spayWrapper.innerHTML = ""
    spayWrapper.appendChild(button)
  }

  React.useEffect(() => {
    if status == "ready" && isSamsungPayReady && isWallet {
      setIsShowOrPayUsing(_ => true)
      addSamsungPayButton()
    }
    None
  }, (status, sessionObj, isSamsungPayReady))

  React.useEffect0(() => {
    let handleSamsung = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("samsungPayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("samsungPayResponse")
        let getBody = SamsungPayHelpers.getSamsungPayBodyFromResponse(~sPayResponse=metadata)
        let body = PaymentBody.samsungPayBody(
          ~metadata=getBody.paymentMethodData->Identity.anyTypeToJson,
        )

        intent(
          ~bodyArr=body,
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      }
      if dict->Dict.get("samsungPayError")->Option.isSome {
        messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
      }
    }
    Window.addEventListener("message", handleSamsung)
    Some(() => {Window.removeEventListener("message", handleSamsung)})
  })

  let isRenderSamsungPayButton = isSamsungPayReady && isWallet

  React.useEffect(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isSamsungPay: isRenderSamsungPayButton,
    })
    None
  }, [isRenderSamsungPayButton])

  <div
    style={height: `${height->Int.toString}px`}
    id="samsungpay-container"
    className={`w-full flex flex-row justify-center rounded-md  [&>*]:w-full [&>button]:!bg-contain`}
  />
}