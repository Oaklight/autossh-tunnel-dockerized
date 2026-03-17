/* ========================================
   SSH Tunnel Manager — Theme & Scheme Switcher
   Part A: Synchronous IIFE (runs before paint)
   Part B: DOMContentLoaded header initialization
   ======================================== */

/* Part A — prevent flash of wrong theme/scheme */
(function() {
    var theme = localStorage.getItem('ssh-tunnel-theme');
    var scheme = localStorage.getItem('ssh-tunnel-scheme');
    if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        document.documentElement.setAttribute('data-theme', 'dark');
    }
    if (scheme && scheme !== 'gold') {
        document.documentElement.setAttribute('data-scheme', scheme);
    }
})();

/* Part B — header initialization (theme toggle, scheme picker, corner links, language) */
document.addEventListener('DOMContentLoaded', function() {

    // ---- Theme toggle (light/dark) ----
    var themeToggle = document.getElementById('themeToggle');
    function updateThemeIcon() {
        var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        themeToggle.querySelector('.material-icons').textContent = isDark ? 'dark_mode' : 'light_mode';
    }
    updateThemeIcon();
    themeToggle.addEventListener('click', function() {
        var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        if (isDark) {
            document.documentElement.removeAttribute('data-theme');
            localStorage.setItem('ssh-tunnel-theme', 'light');
        } else {
            document.documentElement.setAttribute('data-theme', 'dark');
            localStorage.setItem('ssh-tunnel-theme', 'dark');
        }
        updateThemeIcon();
    });

    // ---- Scheme picker ----
    var SCHEMES = [
        { id: 'gold',  color: '#C2922E', darkColor: '#D4A84B' },
        { id: 'teal',  color: '#0D9488', darkColor: '#2DD4BF' },
        { id: 'blue',  color: '#4F6AF0', darkColor: '#6B83F7' },
        { id: 'slate', color: '#475569', darkColor: '#94A3B8' }
    ];

    var schemeToggle = document.getElementById('schemeToggle');
    var schemeDropdown = document.getElementById('schemeDropdown');

    function getCurrentScheme() {
        return localStorage.getItem('ssh-tunnel-scheme') || 'gold';
    }

    function applyScheme(schemeId) {
        if (schemeId === 'gold') {
            document.documentElement.removeAttribute('data-scheme');
        } else {
            document.documentElement.setAttribute('data-scheme', schemeId);
        }
        localStorage.setItem('ssh-tunnel-scheme', schemeId);
        buildSchemeDropdown();
    }

    function getSchemeLabel(schemeId) {
        if (window.i18n) {
            var key = 'navigation.scheme_' + schemeId;
            var translated = window.i18n.t(key);
            if (translated !== key) return translated;
        }
        return schemeId.charAt(0).toUpperCase() + schemeId.slice(1);
    }

    function buildSchemeDropdown() {
        var current = getCurrentScheme();
        var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        schemeDropdown.innerHTML = '';
        SCHEMES.forEach(function(scheme) {
            var item = document.createElement('button');
            item.className = 'scheme-dropdown-item';
            if (scheme.id === current) item.classList.add('active');

            var swatch = document.createElement('span');
            swatch.className = 'scheme-swatch';
            swatch.style.background = isDark ? scheme.darkColor : scheme.color;

            var label = document.createElement('span');
            label.textContent = getSchemeLabel(scheme.id);

            item.appendChild(swatch);
            item.appendChild(label);
            item.addEventListener('click', function(e) {
                e.stopPropagation();
                applyScheme(scheme.id);
                hideSchemeDropdown();
            });
            schemeDropdown.appendChild(item);
        });
    }

    function showSchemeDropdown() {
        buildSchemeDropdown();
        schemeDropdown.classList.add('show');
        document.addEventListener('click', hideSchemeDropdown);
    }

    function hideSchemeDropdown() {
        schemeDropdown.classList.remove('show');
        document.removeEventListener('click', hideSchemeDropdown);
    }

    schemeToggle.addEventListener('click', function(e) {
        e.stopPropagation();
        if (schemeDropdown.classList.contains('show')) {
            hideSchemeDropdown();
        } else {
            showSchemeDropdown();
        }
    });

    // ---- Corner icon links ----
    var dockerhubLink = document.getElementById('dockerhub-link');
    var githubLink = document.getElementById('github-link');
    if (window.PROJECT_CONFIG) {
        if (dockerhubLink) dockerhubLink.href = window.PROJECT_CONFIG.dockerHubUrl;
        if (githubLink) githubLink.href = window.PROJECT_CONFIG.githubUrl;
    }

    // ---- Language dropdown ----
    var languageToggle = document.getElementById('languageToggle');
    var languageDropdown = document.getElementById('languageDropdown');

    function initLanguageDropdown() {
        if (!window.i18n) return;
        var supportedLanguages = window.i18n.getSupportedLanguages();
        var currentLang = window.i18n.getCurrentLanguage();
        languageDropdown.innerHTML = '';
        supportedLanguages.forEach(function(lang) {
            var item = document.createElement('button');
            item.className = 'language-dropdown-item';
            if (lang.code === currentLang) item.classList.add('active');
            item.textContent = lang.name;
            item.addEventListener('click', function(e) {
                e.stopPropagation();
                if (lang.code !== currentLang) window.i18n.switchLanguage(lang.code);
                hideLanguageDropdown();
            });
            languageDropdown.appendChild(item);
        });
    }

    function showLanguageDropdown() {
        initLanguageDropdown();
        languageDropdown.classList.add('show');
        document.addEventListener('click', hideLanguageDropdown);
    }

    function hideLanguageDropdown() {
        languageDropdown.classList.remove('show');
        document.removeEventListener('click', hideLanguageDropdown);
    }

    languageToggle.addEventListener('click', function(e) {
        e.stopPropagation();
        if (languageDropdown.classList.contains('show')) {
            hideLanguageDropdown();
        } else {
            showLanguageDropdown();
        }
    });

    window.addEventListener('languageChanged', function() {
        if (languageDropdown.classList.contains('show')) initLanguageDropdown();
        if (schemeDropdown.classList.contains('show')) buildSchemeDropdown();
    });
    window.addEventListener('i18nReady', function() {
        initLanguageDropdown();
    });
});
