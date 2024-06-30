from enum import Enum
from typing import cast

from selenium.webdriver import (
    Chrome,
    ChromeOptions,
    ChromeService,
    Edge,
    EdgeOptions,
    EdgeService,
    Firefox,
    FirefoxOptions,
    FirefoxService,
    Ie,
    IeOptions,
    IeService,
    Safari,
    SafariOptions,
    SafariService,
    WebKitGTK,
    WebKitGTKOptions,
    WebKitGTKService,
)
from selenium.common.exceptions import NoSuchDriverException
from selenium.webdriver.chromium.options import ChromiumOptions
from selenium.webdriver.common.options import ArgOptions


class BrowserName(Enum):
    any = "any"
    chrome = "chrome"
    edge = "edge"
    safari = "safari"
    firefox = "firefox"
    webkit = "webkit"
    ie = "ie"

    @classmethod
    def from_string(cls, variant: str):
        return cls[variant]


class NoSuchBrowserException(Exception):
    def __init__(self, browser_name: BrowserName) -> None:
        super().__init__(f"Failed to locate {browser_name.value.capitalize()}")


class DriverManager:
    type_driver = Chrome | Edge | Firefox | Safari | WebKitGTK | Ie

    def __init__(self) -> None:
        self.driver: DriverManager.type_driver | None = None

    def close_driver(self) -> None:
        if self.driver:
            self.driver.close()
            self.driver = None

    def setup_driver(self, browser_name: BrowserName, headless=True):
        if self.driver is not None:
            return self.driver

        def setup_options(options: ArgOptions):
            options.add_argument("--disable-extensions")
            options.add_argument("--disable-infobars")
            options.add_argument("--no-sandbox")
            # Doesn't work for some reason reference  HACK: 
            options.add_argument("--log-level=3")
            if isinstance(options, FirefoxOptions):
                if headless:
                    options.add_argument("--headless")
            if isinstance(options, ChromiumOptions):
                # HACK: https://github.com/SeleniumHQ/selenium/issues/13095#issuecomment-1793310460
                options.add_experimental_option("excludeSwitches", ["enable-logging"])
                if headless:
                    options.add_argument("--headless=new")
            return options

        def helper(browser_name: BrowserName):
            try:
                match browser_name:
                    case BrowserName.edge:
                        service_edge = EdgeService()
                        options = cast(EdgeOptions, setup_options(EdgeOptions()))
                        self.driver = Edge(service=service_edge, options=options)
                    case BrowserName.chrome:
                        service_chrome = ChromeService()
                        options = cast(ChromeOptions, setup_options(ChromeOptions()))
                        self.driver = Chrome(service=service_chrome, options=options)
                    case BrowserName.firefox:
                        service_firefox = FirefoxService()
                        options = cast(FirefoxOptions, setup_options(FirefoxOptions()))
                        self.driver = Firefox(service=service_firefox, options=options)
                    case BrowserName.safari:
                        service_safari = SafariService()
                        options = cast(SafariOptions, setup_options(SafariOptions()))
                        self.driver = Safari(service=service_safari, options=options)
                    case BrowserName.webkit:
                        service_webkit = WebKitGTKService()
                        options = cast(
                            WebKitGTKOptions, setup_options(WebKitGTKOptions())
                        )
                        self.driver = WebKitGTK(service=service_webkit, options=options)
                    case BrowserName.ie:
                        service_ie = IeService()
                        options = cast(IeOptions, setup_options(IeOptions()))
                        self.driver = Ie(service=service_ie, options=options)

            except NoSuchDriverException:
                pass

        if browser_name == BrowserName.any:
            for bn in BrowserName:
                helper(bn)
        else:
            helper(browser_name)

        if not self.driver:
            raise NoSuchBrowserException(browser_name)


DRIVER_MANAGER = DriverManager()
