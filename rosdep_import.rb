require 'yaml'
require 'fileutils'
require 'open-uri'

# https://raw.githubusercontent.com/ros/rosdistro/refs/tags/humble/2024-09-19/rosdep/base.yaml
# https://raw.githubusercontent.com/ros/rosdistro/refs/heads/master/rosdep/base.yaml
module Ros2
    class RosdepImporter

        def initialize(osdepfile, rosfile)
            @osdep_file = File.open(osdepfile, 'w')
            @rosfile = File.open(rosfile, 'w')
        end

        def close()
            @osdep_file.close()
            @rosfile.close()
        end

        def check_pip_gem(osentry)
            # puts osentry
            if (osentry.include?("pip")) then
                if osentry["pip"].is_a?(Hash) then
                    @osdep_file.puts "    pip: #{osentry["pip"]["packages"]}"
                else
                    @osdep_file.puts "    pip: #{osentry["pip"]}"
                end
                return true
            end
            if (osentry.include?("gem")) then
                if osentry["gem"].is_a?(Hash) then
                    @osdep_file.puts "    gem: #{osentry["gem"]["packages"]}"
                else
                    @osdep_file.puts "    gem: #{osentry["gem"]}"
                end
                return true
            end
            return false
        end

        def import_rosdep_osdeps(url)
            URI.open(url) do |f|
                yaml = YAML.load(f);    
                yaml.each do |depname, osdep|
                    if osdep["ubuntu"].is_a?(Array) then
                        @osdep_file.puts  depname + ":\n    ubuntu: #{osdep["ubuntu"]}\n\n"
                    elsif osdep["ubuntu"].is_a?(Hash) then
                        @osdep_file.puts  depname + ":"
                        if (!check_pip_gem(osdep["ubuntu"])) then
                            entry = "    ubuntu:\n"
                            is_pip = false
                            osdep["ubuntu"].each do |os, deps|
                                if os == "*" then
                                    os = "default"
                                end
                                if (deps == nil) then
                                    entry += "        " + os + ": nonexistent\n"
                                else
                                    if (!check_pip_gem(deps)) then
                                        entry +=  "        " + os + ": #{deps}\n"
                                    else
                                        is_pip = true
                                    end
                                end
                            end
                            if (!is_pip) then
                                @osdep_file.puts entry
                            end
                        end
                        @osdep_file.puts
                    end
                end
            end
        end

        def import_ros_packages(rosversion)
            url = "https://raw.githubusercontent.com/ros/rosdistro/refs/heads/master/"+rosversion+"/distribution.yaml"
            URI.open(url) do |f|
                yaml = YAML.load(f);    
                yaml["repositories"].each do |depname, content|
                    @rosfile.puts  depname + ":"
                    @rosfile.puts "    ubuntu: ros-"+rosversion+"-"+depname.gsub(/_/, '-')
                    # puts content
                end
            end
        end

    end
end

importer = Ros2::RosdepImporter.new("ubuntu.osdeps-focal", "humble.osdeps")

importer.import_rosdep_osdeps("https://raw.githubusercontent.com/ros/rosdistro/refs/heads/master/rosdep/base.yaml")
importer.import_rosdep_osdeps("https://raw.githubusercontent.com/ros/rosdistro/refs/heads/master/rosdep/python.yaml")
importer.import_rosdep_osdeps("https://raw.githubusercontent.com/ros/rosdistro/refs/heads/master/rosdep/ruby.yaml")

importer.import_ros_packages("humble")
