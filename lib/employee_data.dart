import 'dart:convert';

class Employee {
  String id;
  String name;
  String gender;
  String department;
  String position;
  String contactNumber;
  String email;
  String password;

  Employee({
    required this.id,
    required this.name,
    required this.gender,
    required this.department,
    required this.position,
    required this.contactNumber,
    required this.email,
    required this.password,
  });
}

// ✅ 30 Employees (Your 10 custom + 20 new ones)
const String employeeJson = '''
[
  {
    "id": "12345",
    "name": "Thato Nthabi",
    "gender": "Male",
    "department": "IT",
    "position": "Software Developer",
    "contactNumber": "0780702917",
    "email": "thatonthabi@gmail.com",
    "password": "12345"
  },
  {
    "id": "00000",
    "name": "Zizipho Maganda",
    "gender": "Female",
    "department": "Human Resources",
    "position": "Human Resources (HR) Officer",
    "contactNumber": "0730186120",
    "email": "ziziphomaganda@gmail.com",
    "password": "00000"
  },
  {
    "id": "11111",
    "name": "Lesedi Tlhapane",
    "gender": "Male",
    "department": "Management Department",
    "position": "Supervisor",
    "contactNumber": "0712345678",
    "email": "leseditlhapane@gmail.com",
    "password": "11111"
  },
  {
    "id": "22222",
    "name": "Tshidiso Pitso",
    "gender": "Male",
    "department": "Software Development",
    "position": "Backend Developer",
    "contactNumber": "0723456789",
    "email": "tshidisopsitso@gmail.com",
    "password": "22222"
  },
  {
    "id": "33333",
    "name": "Nonsikelelo Mnguni",
    "gender": "Female",
    "department": "Database Administration",
    "position": "Database Administrator",
    "contactNumber": "0734567890",
    "email": "nonsikelelomnguni@gmail.com",
    "password": "33333"
  },
  {
    "id": "44444",
    "name": "Senelisiwe Ngomti",
    "gender": "Male",
    "department": "IT Infrastructure",
    "position": "Network & Systems Technician",
    "contactNumber": "0745678901",
    "email": "senelisewengomti@gmail.com",
    "password": "44444"
  },
  {
    "id": "55555",
    "name": "Nomsa Dlamini",
    "gender": "Female",
    "department": "Design",
    "position": "UI/UX Designer",
    "contactNumber": "0756789012",
    "email": "nomsadlamini@gmail.com",
    "password": "55555"
  },
  {
    "id": "66666",
    "name": "Tebogo Kgosi",
    "gender": "Male",
    "department": "Quality Assurance",
    "position": "Quality Assurance (QA) Tester",
    "contactNumber": "0767890123",
    "email": "tebogokgosi@gmail.com",
    "password": "66666"
  },
  {
    "id": "77777",
    "name": "Karabo Mhlongo",
    "gender": "Female",
    "department": "Technical Support",
    "position": "IT Support / Helpdesk Officer",
    "contactNumber": "0778901234",
    "email": "karabomhlongo@gmail.com",
    "password": "77777"
  },
  {
    "id": "88888",
    "name": "Tumelo Khumalo",
    "gender": "Male",
    "department": "Business Analysis",
    "position": "Business Analyst / Product Manager",
    "contactNumber": "0789012345",
    "email": "tumelokhumalo@gmail.com",
    "password": "88888"
  },

  {
    "id": "10009", "name": "Lindiwe Phiri", "gender": "Female", "department": "Marketing", "position": "Social Media Manager", "contactNumber": "0711112233", "email": "lindiwe.phiri@gmail.com", "password": "10009"},
  {"id": "10010", "name": "Tshepo Molefe", "gender": "Male", "department": "Finance", "position": "Financial Analyst", "contactNumber": "0722223344", "email": "tshepo.molefe@gmail.com", "password": "10010"},
  {"id": "10011", "name": "Ayanda Mbatha", "gender": "Female", "department": "Human Resources", "position": "Recruitment Specialist", "contactNumber": "0733334455", "email": "ayanda.mbatha@gmail.com", "password": "10011"},
  {"id": "10012", "name": "Neo Radebe", "gender": "Male", "department": "Software Development", "position": "Mobile App Developer", "contactNumber": "0744445566", "email": "neo.radebe@gmail.com", "password": "10012"},
  {"id": "10013", "name": "Palesa Khosa", "gender": "Female", "department": "Administration", "position": "Office Administrator", "contactNumber": "0755556677", "email": "palesa.khosa@gmail.com", "password": "10013"},
  {"id": "10014", "name": "Bongani Mahlangu", "gender": "Male", "department": "Security", "position": "Cybersecurity Analyst", "contactNumber": "0766667788", "email": "bongani.mahlangu@gmail.com", "password": "10014"},
  {"id": "10015", "name": "Kea Motsepe", "gender": "Female", "department": "Operations", "position": "Operations Coordinator", "contactNumber": "0777778899", "email": "kea.motsepe@gmail.com", "password": "10015"},
  {"id": "10016", "name": "Nathi Cele", "gender": "Male", "department": "Procurement", "position": "Procurement Officer", "contactNumber": "0788889900", "email": "nathi.cele@gmail.com", "password": "10016"},
  {"id": "10017", "name": "Dineo Molewa", "gender": "Female", "department": "Public Relations", "position": "Communications Specialist", "contactNumber": "0799990011", "email": "dineo.molewa@gmail.com", "password": "10017"},
  {"id": "10018", "name": "Andile Zungu", "gender": "Male", "department": "Engineering", "position": "Systems Engineer", "contactNumber": "0701011122", "email": "andile.zungu@gmail.com", "password": "10018"},
  {"id": "10019", "name": "Naledi Nkuna", "gender": "Female", "department": "Research & Development", "position": "R&D Specialist", "contactNumber": "0712122233", "email": "naledi.nkuna@gmail.com", "password": "10019"},
  {"id": "10020", "name": "Sibusiso Mdaka", "gender": "Male", "department": "Data Science", "position": "Data Analyst", "contactNumber": "0723233344", "email": "sibusiso.mdaka@gmail.com", "password": "10020"},
  {"id": "10021", "name": "Kgomotso Mokoena", "gender": "Female", "department": "Software Development", "position": "Full Stack Developer", "contactNumber": "0734344455", "email": "kgomotso.mokoena@gmail.com", "password": "10021"},
  {"id": "10022", "name": "Vusi Makhubela", "gender": "Male", "department": "Technical Support", "position": "Systems Support Technician", "contactNumber": "0745455566", "email": "vusi.makhubela@gmail.com", "password": "10022"},
  {"id": "10023", "name": "Zanele Rakhudu", "gender": "Female", "department": "Marketing", "position": "Brand Strategist", "contactNumber": "0756566677", "email": "zanele.rakhudu@gmail.com", "password": "10023"},
  {"id": "10024", "name": "Sabelo Dlamini", "gender": "Male", "department": "Finance", "position": "Payroll Administrator", "contactNumber": "0767677788", "email": "sabelo.dlamini@gmail.com", "password": "10024"},
  {"id": "10025", "name": "Kea Mothapo", "gender": "Female", "department": "Quality Assurance", "position": "QA Lead", "contactNumber": "0778788899", "email": "kea.mothapo@gmail.com", "password": "10025"},
  {"id": "10026", "name": "Lwazi Shabalala", "gender": "Male", "department": "IT Infrastructure", "position": "Cloud Administrator", "contactNumber": "0789899900", "email": "lwazi.shabalala@gmail.com", "password": "10026"},
  {"id": "10027", "name": "Ayanda Nxumalo", "gender": "Female", "department": "Customer Experience", "position": "Client Relations Officer", "contactNumber": "0790901011", "email": "ayanda.nxumalo@gmail.com", "password": "10027"},
  {"id": "10028", "name": "Tumi Seakamela", "gender": "Male", "department": "Business Analysis", "position": "Product Analyst", "contactNumber": "0702021223", "email": "tumi.seakamela@gmail.com", "password": "10028"}
]
''';

List<Employee> employees = [];

void loadEmployees() {
  final List parsed = jsonDecode(employeeJson);
  employees = parsed
      .map((e) => Employee(
            id: e['id'],
            name: e['name'],
            gender: e['gender'],
            department: e['department'],
            position: e['position'],
            contactNumber: e['contactNumber'],
            email: e['email'],
            password: e['password'],
          ))
      .toList();
}

Employee? findEmployee(String input) {
  try {
    return employees.firstWhere(
      (e) => e.id == input || e.name.toLowerCase() == input.toLowerCase(),
    );
  } catch (e) {
    return null;
  }
}
