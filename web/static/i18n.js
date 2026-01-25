/**
 * 国际化 (i18n) 库
 * 支持动态语言切换和本地存储
 */
class I18n {
    constructor() {
        this.currentLang = 'en';
        this.translations = {};
        this.fallbackLang = 'en';
        this.storageKey = 'ssh-tunnel-lang';
        this.supportedLanguages = []; // Will be loaded from API

        // 从本地存储加载语言设置
        this.loadLanguageFromStorage();
    }

    /**
     * 从本地存储加载语言设置
     */
    loadLanguageFromStorage() {
        const savedLang = localStorage.getItem(this.storageKey);
        if (savedLang) {
            this.currentLang = savedLang;
        } else {
            // 检测浏览器语言
            const browserLang = navigator.language || navigator.userLanguage;
            if (browserLang.startsWith('zh-Hant') || browserLang.startsWith('zh-TW') || browserLang.startsWith('zh-HK')) {
                this.currentLang = 'zh-hant';
            } else if (browserLang.startsWith('zh')) {
                this.currentLang = 'zh';
            } else if (browserLang.startsWith('es')) {
                this.currentLang = 'es';
            } else if (browserLang.startsWith('fr')) {
                this.currentLang = 'fr';
            } else if (browserLang.startsWith('ru')) {
                this.currentLang = 'ru';
            } else if (browserLang.startsWith('ja')) {
                this.currentLang = 'ja';
            } else if (browserLang.startsWith('ko')) {
                this.currentLang = 'ko';
            } else if (browserLang.startsWith('ar')) {
                this.currentLang = 'ar';
            }
        }
    }

    /**
     * 保存语言设置到本地存储
     */
    saveLanguageToStorage() {
        localStorage.setItem(this.storageKey, this.currentLang);
    }

    /**
     * 加载语言资源文件
     */
    async loadTranslations(lang) {
        if (this.translations[lang]) {
            return this.translations[lang];
        }

        try {
            const response = await fetch(`/static/locales/${lang}.json`);
            if (!response.ok) {
                throw new Error(`Failed to load ${lang} translations`);
            }
            const translations = await response.json();
            this.translations[lang] = translations;
            return translations;
        } catch (error) {
            console.error(`Error loading translations for ${lang}:`, error);
            if (lang !== this.fallbackLang) {
                return await this.loadTranslations(this.fallbackLang);
            }
            return {};
        }
    }

    /**
     * 获取翻译文本
     */
    t(key, params = {}) {
        const keys = key.split('.');
        let value = this.translations[this.currentLang];

        // 遍历嵌套的键
        for (const k of keys) {
            if (value && typeof value === 'object' && k in value) {
                value = value[k];
            } else {
                // 回退到默认语言
                value = this.translations[this.fallbackLang];
                for (const fallbackKey of keys) {
                    if (value && typeof value === 'object' && fallbackKey in value) {
                        value = value[fallbackKey];
                    } else {
                        console.warn(`Translation key not found: ${key}`);
                        return key; // 返回键名作为后备
                    }
                }
                break;
            }
        }

        if (typeof value !== 'string') {
            console.warn(`Translation value is not a string: ${key}`);
            return key;
        }

        // 替换参数
        return this.interpolate(value, params);
    }

    /**
     * 字符串插值
     */
    interpolate(str, params) {
        return str.replace(/\{\{(\w+)\}\}/g, (match, key) => {
            return params[key] !== undefined ? params[key] : match;
        });
    }

    /**
     * 切换语言
     */
    async switchLanguage(lang) {
        // 验证语言是否在支持的语言列表中
        const supportedCodes = this.supportedLanguages.map(l => l.code);
        if (supportedCodes.length > 0 && !supportedCodes.includes(lang)) {
            console.error(`Unsupported language: ${lang}`);
            return false;
        }

        this.currentLang = lang;
        this.saveLanguageToStorage();

        // 加载新语言的翻译
        await this.loadTranslations(lang);

        // 更新页面内容
        this.updatePageContent();

        // 触发语言切换事件
        window.dispatchEvent(new CustomEvent('languageChanged', {
            detail: { language: lang }
        }));

        return true;
    }

    /**
     * 获取当前语言
     */
    getCurrentLanguage() {
        return this.currentLang;
    }

    /**
     * 从API加载支持的语言列表
     */
    async loadSupportedLanguages() {
        try {
            const response = await fetch('/api/languages');
            if (!response.ok) {
                throw new Error('Failed to load supported languages');
            }
            this.supportedLanguages = await response.json();
            console.log('Loaded supported languages:', this.supportedLanguages);
        } catch (error) {
            console.error('Error loading supported languages:', error);
            // 回退到默认语言列表
            this.supportedLanguages = [
                { code: 'en', name: 'English' },
                { code: 'zh', name: '中文' }
            ];
        }
    }

    /**
     * 获取支持的语言列表
     */
    getSupportedLanguages() {
        return this.supportedLanguages;
    }

    /**
     * 获取语言切换按钮的tooltip文本
     */
    getLanguageToggleTooltip() {
        const languages = this.getSupportedLanguages();
        const languageNames = languages.map(lang => lang.name).join(' / ');
        return `${this.t('navigation.language_toggle_prefix')}: ${languageNames}`;
    }

    /**
     * 初始化国际化
     */
    async init() {
        // 首先加载支持的语言列表
        await this.loadSupportedLanguages();

        // 验证当前语言是否在支持的语言列表中
        const supportedCodes = this.supportedLanguages.map(l => l.code);
        if (supportedCodes.length > 0 && !supportedCodes.includes(this.currentLang)) {
            console.warn(`Current language ${this.currentLang} not supported, falling back to ${this.fallbackLang}`);
            this.currentLang = this.fallbackLang;
            this.saveLanguageToStorage();
        }

        // 加载当前语言和回退语言的翻译
        await Promise.all([
            this.loadTranslations(this.currentLang),
            this.loadTranslations(this.fallbackLang)
        ]);

        // 更新页面内容
        this.updatePageContent();

        // 设置HTML lang属性
        document.documentElement.lang = this.currentLang;

        // 标记i18n已准备就绪
        this.isReady = true;

        // 触发i18n准备就绪事件
        window.dispatchEvent(new CustomEvent('i18nReady', {
            detail: { language: this.currentLang }
        }));

        return true;
    }

    /**
     * 更新页面内容
     */
    updatePageContent() {
        // 更新所有带有 data-i18n 属性的元素
        const elements = document.querySelectorAll('[data-i18n]');
        elements.forEach(element => {
            const key = element.getAttribute('data-i18n');
            const translation = this.t(key);

            if (element.tagName === 'INPUT' && element.type === 'text') {
                element.placeholder = translation;
            } else if (element.hasAttribute('title')) {
                element.title = translation;
            } else {
                element.textContent = translation;
            }
        });

        // 更新页面标题
        const titleKey = document.body.getAttribute('data-page-title');
        if (titleKey) {
            document.title = this.t(titleKey);
        }

        // 更新特殊元素
        this.updateSpecialElements();
    }

    /**
     * 更新特殊元素（需要特殊处理的元素）
     */
    updateSpecialElements() {
        // 更新表格头部
        const tableHeaders = document.querySelectorAll('th[data-i18n]');
        tableHeaders.forEach(th => {
            const key = th.getAttribute('data-i18n');
            th.textContent = this.t(key);
        });

        // 更新按钮文本
        const buttons = document.querySelectorAll('button[data-i18n]');
        buttons.forEach(button => {
            const key = button.getAttribute('data-i18n');
            const labelElement = button.querySelector('.mdc-button__label');
            if (labelElement) {
                labelElement.textContent = this.t(key);
            } else {
                button.textContent = this.t(key);
            }
        });

        // 更新选择框选项
        const selectOptions = document.querySelectorAll('option[data-i18n]');
        selectOptions.forEach(option => {
            const key = option.getAttribute('data-i18n');
            option.textContent = this.t(key);
        });

        // 更新输入框占位符
        const inputsWithPlaceholder = document.querySelectorAll('input[data-i18n-placeholder]');
        inputsWithPlaceholder.forEach(input => {
            const key = input.getAttribute('data-i18n-placeholder');
            input.placeholder = this.t(key);
        });

        // 更新title属性
        const elementsWithTitle = document.querySelectorAll('[data-i18n-title]');
        elementsWithTitle.forEach(element => {
            const key = element.getAttribute('data-i18n-title');
            element.title = this.t(key);
        });

        // Tooltip属性由tooltip系统自己处理，这里不需要设置data-tooltip
        // 新的tooltip系统会直接读取data-i18n-tooltip并调用this.t()

        // 重新生成所有表格行以更新动态内容
        this.updateTableRows();
    }

    /**
     * 更新表格行中的动态内容
     */
    updateTableRows() {
        // 这个方法会在语言切换时被调用，用于更新已存在的表格行
        // 由于表格行是动态生成的，我们需要重新设置它们的内容
        const tableRows = document.querySelectorAll('#tunnelTable tbody tr');
        tableRows.forEach(row => {
            // 更新状态文本
            const statusCell = row.cells[1];
            if (statusCell) {
                const statusSpan = statusCell.querySelector('span');
                if (statusSpan) {
                    const statusText = statusSpan.textContent.trim();
                    let translatedStatus = statusText;

                    // 根据当前状态文本反向查找并翻译
                    if (statusText === 'RUNNING' || statusText === '运行中') {
                        translatedStatus = this.t('table.status.running');
                    } else if (statusText === 'NORMAL' || statusText === '正常') {
                        translatedStatus = this.t('table.status.normal');
                    } else if (statusText === 'DEAD' || statusText === '已停止') {
                        translatedStatus = this.t('table.status.dead');
                    } else if (statusText === 'STARTING' || statusText === '启动中') {
                        translatedStatus = this.t('table.status.starting');
                    } else if (statusText === 'STOPPED' || statusText === '已停止') {
                        translatedStatus = this.t('table.status.stopped');
                    } else if (statusText === 'N/A' || statusText === '不可用') {
                        translatedStatus = this.t('table.status.na');
                    }

                    statusSpan.textContent = translatedStatus;
                }
            }

            // 更新交互认证按钮的title
            const interactiveButton = row.querySelector('.interactive-toggle-button');
            if (interactiveButton) {
                const isActive = interactiveButton.classList.contains('active');
                const enabledText = this.t('buttons.interactive_auth_enabled');
                const disabledText = this.t('buttons.interactive_auth_disabled');
                interactiveButton.title = isActive ? enabledText : disabledText;
            }

            // 更新删除按钮的title
            const deleteButton = row.querySelector('.delete-button');
            if (deleteButton) {
                deleteButton.title = this.t('buttons.delete');
            }
        });
    }

    /**
     * 为动态添加的内容设置翻译
     */
    translateElement(element, key, type = 'text') {
        const translation = this.t(key);

        switch (type) {
            case 'placeholder':
                element.placeholder = translation;
                break;
            case 'title':
                element.title = translation;
                break;
            case 'text':
            default:
                element.textContent = translation;
                break;
        }

        // 添加 data-i18n 属性以便后续更新
        element.setAttribute('data-i18n', key);
    }
}

// 创建全局实例
window.i18n = new I18n();

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', async () => {
    await window.i18n.init();
    console.log(`I18n initialized with language: ${window.i18n.getCurrentLanguage()}`);
});