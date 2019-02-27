using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net;
using System.Net.Mail;

namespace vpn_watcher
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("---Start---");
            var smtp = new SmtpClient
            {
                Host = "smtp.sendgrid.net",
                Port = 587,
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential("azure_xxxxxxxxxxxxxxxxxxxxxxx123d@azure.com", "mypassword")
            };

            var ipAddress = System.Net.IPAddress.Parse("10.10.10.10");
            int destPort = 8201;
            MailMessage mail = new MailMessage();
            mail.To.Add("admin1@domain.com");
            mail.To.Add("admin2@domain.com");
            mail.From = new MailAddress("alert-noreply@azurewebjobs.com");
            mail.Subject = "Production Server Unreachable";

            mail.Body = ("Hi, the production server (10.10.10.10:8201) is not reachable over the VPN");

            try
            {
                var socket = new System.Net.Sockets.TcpClient();
                socket.Connect(ipAddress, destPort);
                if (socket.Connected)
                {
                    socket.Close();
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
                Console.WriteLine("Sending email...");
                smtp.Send(mail);
            }
            Console.WriteLine("---End---");

        }
    }
}
