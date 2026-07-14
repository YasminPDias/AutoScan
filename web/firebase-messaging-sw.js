importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDFeQ3OTOvFfxsFnLf1b_PyKz1Sxef4gJo',
  authDomain: 'autex-8e341.firebaseapp.com',
  projectId: 'autex-8e341',
  storageBucket: 'autex-8e341.firebasestorage.app',
  messagingSenderId: '171359096707',
  appId: '1:171359096707:web:900992882e26e7b6a230b6',
});

const messaging = firebase.messaging();

// mensagens recebidas com a aba em background ou fechada
messaging.onBackgroundMessage((payload) => {
  const { titulo, corpo } = payload.data || {};
  self.registration.showNotification(titulo || 'Nova notificação', {
    body: corpo || '',
     icon: '../lib/assets/Logo Autex.png', // ajusta pro ícone real do seu PWA, se o caminho for outro
    data: payload.data,
  });
});

// clique na notificação — só isso aqui roda quando a aba estava fechada,
// já que nesse caso o código Dart (onMessageOpenedApp/getInitialMessage)
// não está rodando pra capturar o toque
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const conversaId = event.notification.data?.conversaId;
  const urlToOpen = self.location.origin + (conversaId ? `/?conversaId=${conversaId}` : '/');

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          client.navigate(urlToOpen);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    }),
  );
});
