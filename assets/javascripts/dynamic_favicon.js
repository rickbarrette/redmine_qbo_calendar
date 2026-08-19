(function() {
  'use strict';

  console.log('[Redmine QBO Calendar] dynamic_favicon.js loaded (Simplified Canvas PNG)');

  const FAVICON_ID = 'redmine-qbo-calendar-favicon';

  function generatePngFaviconUrl(day, callback) {
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg"
           width="64" height="64" viewBox="0 0 64 64">

        <rect
          x="3"
          y="4"
          width="58"
          height="57"
          rx="7"
          fill="#ffffff"
          stroke="#888888"
          stroke-width="2"/>

        <rect
          x="3"
          y="4"
          width="58"
          height="18"
          rx="7"
          fill="#d92626"/>

        <rect
          x="3"
          y="15"
          width="58"
          height="7"
          fill="#d92626"/>

        <rect
          x="14"
          y="1"
          width="6"
          height="12"
          rx="3"
          fill="#555555"/>

        <rect
          x="44"
          y="1"
          width="6"
          height="12"
          rx="3"
          fill="#555555"/>

        <text
          x="32"
          y="17"
          text-anchor="middle"
          font-family="Arial, sans-serif"
          font-size="8"
          font-weight="bold"
          fill="#ffffff">
          OSOR
        </text>

        <text
          x="32"
          y="50"
          text-anchor="middle"
          font-family="Arial, sans-serif"
          font-size="36"
          font-weight="bold"
          fill="#222222">
          ${day}
        </text>

      </svg>
    `;

    const cleanSvg = svg.replace(/\n/g, '').replace(/\s+/g, ' ').trim();
    const svgDataUrl = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(cleanSvg)));

    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d');

    const img = new Image();
    
    img.onload = function() {
      ctx.drawImage(img, 0, 0, 64, 64);
      const pngDataUrl = canvas.toDataURL('image/png');
      callback(pngDataUrl);
    };
    
    img.src = svgDataUrl;
  }

  function setFavicon() {
    const day = new Date().getDate();

    generatePngFaviconUrl(day, function(newFaviconUrl) {
      const existingIcons = document.querySelectorAll('link[rel*="icon"]');

      if (existingIcons.length > 0) {
        existingIcons.forEach(function(icon) {
          icon.type = 'image/png';
          icon.rel = 'icon'; 
          icon.href = newFaviconUrl;
        });
      } else {
        const favicon = document.createElement('link');
        favicon.id = FAVICON_ID;
        favicon.rel = 'icon';
        favicon.type = 'image/png';
        favicon.href = newFaviconUrl;
        document.head.appendChild(favicon);
      }

      console.log(
        '[OSOR Calendar] favicon updated (Simplified PNG)',
        { day: day }
      );
    });
  }

  function initialize() {
    console.log('[OSOR Calendar] initializing favicon');
    setTimeout(setFavicon, 150);
  }

  if (document.readyState === 'loading') {
    document.addEventListener(
      'DOMContentLoaded',
      initialize
    );
  } else {
    initialize();
  }

})();