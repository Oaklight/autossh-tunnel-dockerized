/**
 * Universal Tooltip System
 * Automatically handles tooltips for elements with data-tooltip or data-i18n-tooltip attributes
 * Supports internationalization and automatic positioning
 */

class TooltipManager {
    constructor() {
        this.tooltips = new Map();
        this.activeTooltip = null;
        this.init();
    }

    init() {
        // Wait for i18n to be ready before initializing tooltips
        if (window.i18n && window.i18n.isReady) {
            this.initializeTooltips();
        } else {
            // Wait for i18n to be ready
            const checkI18n = () => {
                if (window.i18n && window.i18n.isReady) {
                    this.initializeTooltips();
                } else {
                    setTimeout(checkI18n, 50);
                }
            };
            checkI18n();
        }

        // Listen for language changes to update tooltip text
        window.addEventListener('languageChanged', () => {
            this.updateTooltipTexts();
        });

        // Listen for i18n ready event
        window.addEventListener('i18nReady', () => {
            if (this.tooltips.size === 0) {
                this.initializeTooltips();
            } else {
                this.updateTooltipTexts();
            }
        });

        // Handle dynamic content
        this.observeDOM();
    }

    initializeTooltips() {
        // Find all elements with tooltip attributes
        const tooltipElements = document.querySelectorAll('[data-tooltip], [data-i18n-tooltip]');

        tooltipElements.forEach(element => {
            this.createTooltip(element);
        });
    }

    createTooltip(element) {
        // Skip if tooltip already exists
        if (this.tooltips.has(element)) {
            return;
        }

        // Create tooltip element
        const tooltip = document.createElement('div');
        tooltip.className = 'universal-tooltip';
        document.body.appendChild(tooltip);

        // Store tooltip reference
        this.tooltips.set(element, tooltip);

        // Set initial text
        this.updateTooltipText(element, tooltip);

        // Add event listeners
        element.addEventListener('mouseenter', (e) => this.showTooltip(e, element, tooltip));
        element.addEventListener('mouseleave', () => this.hideTooltip(tooltip));
        element.addEventListener('focus', (e) => this.showTooltip(e, element, tooltip));
        element.addEventListener('blur', () => this.hideTooltip(tooltip));
    }

    updateTooltipText(element, tooltip) {
        let text = '';

        // Special handling for language toggle button
        if (element.id === 'languageToggle' && window.i18n && window.i18n.getLanguageToggleTooltip) {
            text = window.i18n.getLanguageToggleTooltip();
        } else {
            // Check for i18n tooltip first
            const i18nKey = element.getAttribute('data-i18n-tooltip');
            if (i18nKey && window.i18n) {
                text = window.i18n.t(i18nKey);
            }

            // Fallback to static tooltip (but skip "dynamic" placeholder)
            if (!text) {
                const tooltipAttr = element.getAttribute('data-tooltip') || '';
                if (tooltipAttr !== 'dynamic') {
                    text = tooltipAttr;
                }
            }
        }

        tooltip.textContent = text;
    }

    updateTooltipTexts() {
        // Update all tooltip texts when language changes
        this.tooltips.forEach((tooltip, element) => {
            this.updateTooltipText(element, tooltip);
        });
    }

    showTooltip(event, element, tooltip) {
        // Hide any active tooltip
        if (this.activeTooltip && this.activeTooltip !== tooltip) {
            this.hideTooltip(this.activeTooltip);
        }

        // Update text in case it changed
        this.updateTooltipText(element, tooltip);

        // Don't show empty tooltips
        if (!tooltip.textContent.trim()) {
            return;
        }

        // Position tooltip
        this.positionTooltip(element, tooltip);

        // Show tooltip
        tooltip.classList.add('show');
        this.activeTooltip = tooltip;
    }

    hideTooltip(tooltip) {
        tooltip.classList.remove('show');
        if (this.activeTooltip === tooltip) {
            this.activeTooltip = null;
        }
    }

    positionTooltip(element, tooltip) {
        const rect = element.getBoundingClientRect();
        const tooltipRect = tooltip.getBoundingClientRect();
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

        // Reset classes
        tooltip.className = 'universal-tooltip show';

        // Calculate positions
        const spaceAbove = rect.top;
        const spaceBelow = viewportHeight - rect.bottom;
        const spaceLeft = rect.left;
        const spaceRight = viewportWidth - rect.right;

        let top, left;
        let position = 'top'; // default position

        // Determine best position
        if (spaceAbove >= tooltipRect.height + 10) {
            // Position above
            position = 'top';
            top = rect.top + scrollTop - tooltipRect.height - 10;
        } else if (spaceBelow >= tooltipRect.height + 10) {
            // Position below
            position = 'bottom';
            top = rect.bottom + scrollTop + 10;
        } else if (spaceRight >= tooltipRect.width + 10) {
            // Position right
            position = 'right';
            top = rect.top + scrollTop + (rect.height - tooltipRect.height) / 2;
        } else if (spaceLeft >= tooltipRect.width + 10) {
            // Position left
            position = 'left';
            top = rect.top + scrollTop + (rect.height - tooltipRect.height) / 2;
        } else {
            // Default to top if no space
            position = 'top';
            top = rect.top + scrollTop - tooltipRect.height - 10;
        }

        // Calculate horizontal position
        if (position === 'top' || position === 'bottom') {
            left = rect.left + scrollLeft + (rect.width - tooltipRect.width) / 2;

            // Keep tooltip within viewport
            if (left < 10) {
                left = 10;
            } else if (left + tooltipRect.width > viewportWidth - 10) {
                left = viewportWidth - tooltipRect.width - 10;
            }
        } else if (position === 'right') {
            left = rect.right + scrollLeft + 10;
        } else if (position === 'left') {
            left = rect.left + scrollLeft - tooltipRect.width - 10;
        }

        // Apply position
        tooltip.style.top = `${top}px`;
        tooltip.style.left = `${left}px`;
        tooltip.classList.add(`position-${position}`);
    }

    observeDOM() {
        // Watch for dynamically added elements
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        // Check if the added node has tooltip attributes
                        if (node.hasAttribute('data-tooltip') || node.hasAttribute('data-i18n-tooltip')) {
                            this.createTooltip(node);
                        }

                        // Check for tooltip elements within the added node
                        const tooltipElements = node.querySelectorAll('[data-tooltip], [data-i18n-tooltip]');
                        tooltipElements.forEach(element => {
                            this.createTooltip(element);
                        });
                    }
                });
            });
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    destroy() {
        // Clean up all tooltips
        this.tooltips.forEach((tooltip, element) => {
            tooltip.remove();
        });
        this.tooltips.clear();
        this.activeTooltip = null;
    }
}

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.tooltipManager = new TooltipManager();
});

// Export for manual initialization if needed
window.TooltipManager = TooltipManager;