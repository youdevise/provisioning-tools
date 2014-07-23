metadata    :name        => "SimpleRPC Agent For retrieving VG details",
            :description => "Agent to query VG details via MCollective",
            :author      => "Gary R",
            :url         => "http://timgroup.com",
            :license     => "MIT",
            :version     => "1.0",
            :timeout     => 10

action "details", :description => "returns all storage details for various storage types" do
   display :always
end
