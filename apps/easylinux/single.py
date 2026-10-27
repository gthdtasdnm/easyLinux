"""Nur eine Instanz pro Programm: ein zweiter Start bittet die laufende Instanz, sich zu zeigen."""
from PySide6.QtNetwork import QLocalServer, QLocalSocket


def notify_running(name, message=b"show"):
    sock = QLocalSocket()
    sock.connectToServer(name)
    if sock.waitForConnected(300):
        sock.write(message)
        sock.waitForBytesWritten(300)
        sock.disconnectFromServer()
        return True
    return False


def listen(name, on_message):
    QLocalServer.removeServer(name)
    server = QLocalServer()
    server.listen(name)

    def accept():
        conn = server.nextPendingConnection()
        conn.waitForReadyRead(300)
        on_message(bytes(conn.readAll()).decode())
        conn.disconnectFromServer()

    server.newConnection.connect(accept)
    return server
